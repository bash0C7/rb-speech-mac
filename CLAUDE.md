# CLAUDE.md — rb-speech-mac

## Position

Ruby binding for Apple's Speech framework on macOS, exposed as singleton methods on `SpeechMac`. Implementation is a **subprocess client**: Ruby spawns a separately-signed Swift CLI helper (`SpeechMacHelper`) for each call. The helper has its own `Info.plist` with `NSSpeechRecognitionUsageDescription` embedded into the Mach-O via `-sectcreate __TEXT __info_plist`, so TCC sees a valid identity and lets `SFSpeechRecognizer.requestAuthorization()` work without crashing.

Sibling of `rb-vision-ocrmac`, but architecturally diverged: that gem is a thin C+Swift dylib loaded into the Ruby process, while this one runs Speech.framework in a separate process to satisfy TCC. Scaffold parity with `swift_gem new` no longer holds for this repo.

## Core design principles

1. **Subprocess isolation for TCC.** The Ruby interpreter never loads Speech.framework code — it spawns the helper. TCC permission attaches to the helper's identity (cdhash for ad-hoc, designated requirement for Apple Development cert), independent of the Ruby host.
2. **Source-only distribution, build at install time.** No precompiled binaries shipped. `extconf.rb` writes a custom Makefile that runs `swift build` and `codesign` during `gem install` / `bundle install`. The user gets the helper compiled and signed for their own machine.
3. **Explicit error reporting via `Data`.** Failures don't return `""` — they return a `Result` (or `AuthorizationResult`) Data with `success: false` and an `error:` field carrying the specific Exception subclass. Callers can pattern-match or `raise result.error`.
4. **Fixed defaults for Speech behavior.** Locale `en-US`, `shouldReportPartialResults = false`, 30s timeout. Changes go through new API methods.
5. **No promise of thread safety.** Each call spawns its own subprocess. Concurrent calls work in practice (independent processes) but no synchronization is provided.

## Public API

| Method | Returns | Notes |
|---|---|---|
| `SpeechMac.transcribe(path)` | `SpeechMac::Result` | Reads helper's cached authorization status (does not show dialog). On `:not_determined` returns `Result(success: false, error: NotAuthorizedError)` — caller should run `authorize` first. |
| `SpeechMac.authorize` | `SpeechMac::AuthorizationResult` | Triggers the macOS Speech Recognition permission dialog if status is `.notDetermined`. Caches grant for subsequent runs of the same helper binary (cdhash). |
| `SpeechMac.helper_path` | String | Resolved helper binary path; defaults to `<gem_root>/lib/speech_mac/SpeechMacHelper`. |
| `SpeechMac.helper_path=` | — | Override the resolved path (mainly for testing). |

### `Result` shape

`Result = Data.define(:text, :success, :error)`

| field | success | failure |
|---|---|---|
| `text` | transcribed String | `nil` |
| `success` | `true` | `false` |
| `error` | `nil` | Exception instance |

### `AuthorizationResult` shape

`AuthorizationResult = Data.define(:status, :success, :error)`

| field | success | failure |
|---|---|---|
| `status` | `:authorized` | `:denied` / `:restricted` / `:not_determined` / `:unknown` |
| `success` | `true` | `false` |
| `error` | `nil` | Exception instance (typically `NotAuthorizedError` or `HelperSpawnError`) |

### Error hierarchy

All under `SpeechMac::Error < StandardError`:

| Class | When |
|---|---|
| `NotAuthorizedError` | Helper exit 2 (status not `.authorized`) |
| `RecognizerUnavailableError` | Helper exit 3 (recognizer offline or locale unsupported) |
| `FileNotFoundError` | Helper exit 4 (audio path missing or empty) |
| `TimeoutError` | Helper exit 5 (30s recognition timeout) |
| `Error` (generic) | Helper exit 6 (Apple framework error; `.message` carries stderr) |
| `HelperCrashError` | Unexpected non-zero exit |
| `HelperSpawnError` | Ruby couldn't spawn the helper (binary missing / not executable) |

## Architecture

```
[caller (Ruby)]
  │
  │   SpeechMac.transcribe(path) → Result
  ▼
lib/speech_mac.rb              ← public API + helper_path resolution
  │
  ▼
lib/speech_mac/helper_client.rb  ← Open3.capture3 + exit code → Error mapping
  │
  │   Process.spawn (separate process, separate TCC identity)
  ▼
lib/speech_mac/SpeechMacHelper   ← signed Mach-O with embedded Info.plist
  │
  ▼
ext/speech_mac/Sources/SpeechMacHelper/{main,Transcribe,Authorize}.swift
  │
  ▼
[Apple Speech framework]
```

## Module boundaries

| Layer | Responsibility |
|---|---|
| `lib/speech_mac.rb` | Public module; defines `SpeechMac.transcribe` / `.authorize` / `.helper_path`; resolves default helper path |
| `lib/speech_mac/errors.rb` | Error class hierarchy |
| `lib/speech_mac/result.rb` | `Result` and `AuthorizationResult` Data classes |
| `lib/speech_mac/helper_client.rb` | Subprocess invocation, stdout/stderr capture, exit code → Error mapping |
| `lib/speech_mac/SpeechMacHelper` | Built-and-installed helper binary (artifact, not git-tracked) |
| `ext/speech_mac/extconf.rb` | Detects codesign identity (env > Apple Development cert > ad-hoc); writes Makefile that runs `swift build` + `codesign --identifier <bundle_id>` + installs binary |
| `ext/speech_mac/Sources/SpeechMacHelper/main.swift` | CLI subcommand dispatch (`transcribe` / `authorize`) |
| `ext/speech_mac/Sources/SpeechMacHelper/Transcribe.swift` | `SFSpeechURLRecognitionRequest` driver, 30s `DispatchSemaphore` timeout |
| `ext/speech_mac/Sources/SpeechMacHelper/Authorize.swift` | `SFSpeechRecognizer.requestAuthorization` wrapper, prints status to stdout |
| `ext/speech_mac/Resources/Info.plist` | Embedded into Mach-O via `-sectcreate __TEXT __info_plist`. Contains `CFBundleIdentifier=com.bash0c7.rb-speech-mac.helper` and `NSSpeechRecognitionUsageDescription` |
| `ext/speech_mac/Package.swift` | Single `executableTarget`; `linkerSettings` injects the `__info_plist` section |

## Helper IPC protocol

```
SpeechMacHelper transcribe <audio-path>
SpeechMacHelper authorize
```

**stdin**: not used.
**stdout**: success payload (transcription text for `transcribe`, status name for `authorize`).
**stderr**: human-readable error detail; surfaced into `Error.message` on failure.
**exit code**:

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Usage error (bad argv) |
| 2 | Not authorized (status ≠ `.authorized`) |
| 3 | Recognizer unavailable for locale |
| 4 | Audio file not found / empty path |
| 5 | 30s recognition timeout |
| 6 | Apple framework recognition error |
| other | Treated by Ruby as `HelperCrashError` |

## Codesigning

Identity selection in `extconf.rb` is C → B → A:

1. **C** — `SPEECH_MAC_CODESIGN_IDENTITY` env var (explicit override, takes precedence).
2. **B** — first `Apple Development:` cert from `security find-identity -v -p codesigning`.
3. **A** — ad-hoc (`-`).

`codesign --force --identifier com.bash0c7.rb-speech-mac.helper` is always passed so the Info.plist is bound to the signature (`Info.plist=bound` in `codesign -dv`); without `--identifier`, ad-hoc signatures default to the binary basename and the plist is reported as `not bound`.

**TCC and rebuild**: ad-hoc-signed binaries are tracked by cdhash. Rebuilding (e.g. on every `gem install`) changes the cdhash, so the user has to re-grant Speech Recognition permission. Installing an Apple Development identity (free Apple ID via Xcode) gives a stable designated requirement that survives rebuilds.

## Build flow

```
bundle exec rake compile
```

Equivalently, during `gem install` / `bundle install` (via `spec.extensions = ["ext/speech_mac/extconf.rb"]`), RubyGems runs:

```
ruby extconf.rb           # writes Makefile, prints chosen identity
make install              # swift build → codesign → install -m 755 → lib/speech_mac/SpeechMacHelper
```

`bundle exec rake test` runs the unit tests (which use `test/fixtures/fake_helper.sh`, so they don't need the real helper built).

## TDD discipline

t-wada style RED → GREEN → REFACTOR independent commits. test-unit. Fixtures: `test/fixtures/sample.aiff` (macOS `say -v Samantha`, ~135 KB) and `test/fixtures/fake_helper.sh` (driven by `FAKE_EXIT` / `FAKE_STDOUT` / `FAKE_STDERR` env vars to exercise `HelperClient` exit-code mapping without the real Swift helper).

## Related projects

- `~/dev/src/github.com/bash0C7/rb-vision-ocrmac` — sibling for Vision.framework (no TCC issue, stays as in-process C+Swift dylib).
- `~/dev/src/github.com/bash0C7/rb-record-transcribe-mac` — different stack (FFmpeg + MLX Whisper); kept as a non-Speech-framework alternative.
- `~/dev/src/github.com/bash0C7/swift_gem` — scaffold/Mkmf framework. **Not used** by this repo since the build no longer produces a Ruby C extension.

## Environment requirements

macOS 12+, Apple Silicon, Swift 6.0+, Ruby 3.2+ (`Data.define` is required), bundler 4.x. `say` available (default on macOS) for fixture regeneration. Optional but recommended: an Apple Development signing identity in the keychain for stable TCC permission across rebuilds.

## Prohibitions

- No Python source.
- Do not git-track `Gemfile.lock`.
- Do not add live microphone capture (AVAudioEngine) here — file-based only.
- Do not promise thread safety for concurrent calls.
- Do not cache, normalize, or post-process transcription results here.
- Do not call `SFSpeechRecognizer.requestAuthorization` from anything other than the helper subprocess (the Ruby interpreter has no `NSSpeechRecognitionUsageDescription` and would be killed by TCC).
- Commit messages in English, conventional commits style.
- `.claude/` is committed.
