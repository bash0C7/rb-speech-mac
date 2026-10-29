# CLAUDE.md — rb-speech-mac

## Position

Ruby binding for Apple's Speech framework on macOS, exposed as singleton methods on `SpeechMac`. Ruby spawns the `SpeechMacHelper` subprocess, a Swift Package Manager executable, for each call. The helper embeds an `Info.plist` with `NSSpeechRecognitionUsageDescription` into its Mach-O via `-sectcreate __TEXT __info_plist`, so TCC sees a valid identity and `SFSpeechRecognizer.requestAuthorization` works. Scaffolded from `bash0C7/swift_gem`. Sibling of `rb-translation-mac`, which uses the same helper subprocess layout.

## Core design principles

1. **Subprocess isolation for TCC.** The Ruby interpreter never loads Speech.framework code. TCC permission attaches to the helper's signature: the code hash for ad hoc, the designated requirement for an Apple Development identity. The helper re-executes itself once with `responsibility_spawnattrs_setdisclaim` so TCC treats it, not the terminal or Ruby host, as the responsible process.
2. **Source-only distribution, build at install time.** No precompiled binaries ship. `extconf.rb` writes a Makefile that runs `xcrun swift build` and `codesign` during `gem install`; `rake compile` runs the same `extconf.rb` and `make install`.
3. **Result values for domain failures; raise for preconditions.** TCC denied, Siri off, recognizer unavailable, 30-second timeout, Speech framework errors, and helper failures return a `Result` or `AuthorizationResult` with `success: false` and `error` set. A missing audio path raises `Errno::ENOENT` before the helper runs.
4. **Fixed defaults for Speech behavior.** Locale `en-US`, `shouldReportPartialResults = false`, `requiresOnDeviceRecognition = true`, 30-second recognition timeout, 60-second authorization timeout. Changes go through new API methods.
5. **No promise of thread safety.** Each call spawns its own subprocess.
6. **Scaffold parity where it applies.** `xcrun swift`, `swift-tools-version: 6.4`, `.macOS(.v27)`, `task :swift`, `task compile: :swift`, `task :rbs`, `task test: %i[rbs compile]`, `sig/`, and the tracked `.bundle/config` follow swift_gem. The scaffold's C extension pieces (`swift_mkmf.rb`, `<m>.c`, `@c` bridge, `Rake::ExtensionTask`, `rake-compiler`) do not apply because nothing runs in the Ruby process; `extconf.rb` builds the helper instead of a C extension.

## Public API

| Method | Returns | Notes |
|---|---|---|
| `SpeechMac.transcribe(path)` | `SpeechMac::Result` | Raises `Errno::ENOENT` if `path` doesn't exist. Reads the helper's granted status without showing the dialog; `:not_determined` returns `NotAuthorizedError` |
| `SpeechMac.authorize` | `SpeechMac::AuthorizationResult` | Shows the Speech Recognition dialog while the status is `.notDetermined` |
| `SpeechMac.helper_path` | String | Defaults to `<gem_root>/lib/speech_mac/SpeechMacHelper` |
| `SpeechMac.helper_path=` | — | Overrides the helper path (used by tests) |

`Result = Data.define(:text, :success, :error)` and `AuthorizationResult = Data.define(:status, :success, :error)`. `status` is `:authorized`, `:denied`, `:restricted`, `:not_determined`, or `:unknown`.

### Error hierarchy

All under `SpeechMac::Error < StandardError`:

| Class | When |
|---|---|
| `NotAuthorizedError` | Helper exit 2; for `authorize`, any non-zero exit other than 5 |
| `RecognizerUnavailableError` | Helper exit 3 |
| `FileNotFoundError` | Helper exit 4 (the file disappeared after the Ruby-side existence check) |
| `TimeoutError` | Helper exit 5 |
| `Error` | Helper exit 6 (Speech framework error; `message` carries stderr) |
| `HelperCrashError` | Killed by a signal or an unexpected exit code |
| `HelperSpawnError` | Ruby could not spawn the helper |

## Architecture

```
[caller (Ruby)]
  │
  ▼
lib/speech_mac.rb                ← public API, helper_path accessors
  │
  ▼
lib/speech_mac/helper_client.rb  ← Open3.capture3, exit code → Result / AuthorizationResult
  │
  ▼
lib/speech_mac/SpeechMacHelper   ← signed Mach-O with embedded Info.plist
  ├─ re-exec with TCC responsibility disclaimed
  ├─ transcribe → SFSpeechURLRecognitionRequest, CFRunLoopRunInMode with 30 s limit
  └─ authorize  → SFSpeechRecognizer.requestAuthorization, CFRunLoopRunInMode with 60 s limit
```

## Module boundaries

| Layer | Responsibility |
|---|---|
| `lib/speech_mac.rb` | `DEFAULT_HELPER_PATH`, `helper_path` accessors, `transcribe`, `authorize` |
| `lib/speech_mac/errors.rb` | Error hierarchy |
| `lib/speech_mac/result.rb` | `Result` and `AuthorizationResult` |
| `lib/speech_mac/helper_client.rb` | Runs the helper, maps exit codes and output to Ruby values |
| `sig/speech_mac.rbs` | RBS and API documentation for everything above |
| `ext/speech_mac/extconf.rb` | Chooses the codesign identity and writes the Makefile that builds, signs, and installs the helper |
| `ext/speech_mac/Package.swift` | `SpeechMacHelper` executable product; `linkerSettings` embed `Resources/Info.plist` |
| `ext/speech_mac/Sources/SpeechMacHelper/main.swift` | Disclaim re-exec, subcommand dispatch |
| `ext/speech_mac/Sources/SpeechMacHelper/Disclaim.swift` | `reexecWithDisclaim` via `posix_spawn` with `responsibility_spawnattrs_setdisclaim` |
| `ext/speech_mac/Sources/SpeechMacHelper/Transcribe.swift` | `transcribe(path:)`, `warn` |
| `ext/speech_mac/Sources/SpeechMacHelper/Authorize.swift` | `authorize()` |
| `ext/speech_mac/Resources/Info.plist` | `CFBundleIdentifier=com.bash0c7.rb-speech-mac.helper`, `NSSpeechRecognitionUsageDescription` |
| `Rakefile` | `task :swift` (`extconf.rb` + `make install`), `task compile: :swift`, `task :clean`, `task :rbs`, `task test: %i[rbs compile]`, `task console: :compile` |

## Helper IPC protocol

```
SpeechMacHelper transcribe <audio-path>
SpeechMacHelper authorize
```

Standard output carries the transcription or the status name without a trailing newline. Standard error carries the failure message.

| Exit | Meaning |
|---|---|
| 0 | Success |
| 1 | Usage error |
| 2 | Not authorized |
| 3 | Recognizer or on-device model unavailable for `en-US` |
| 4 | Audio file not found or empty path |
| 5 | Timeout (30 s recognition, 60 s authorization) |
| 6 | Speech framework recognition error |

## Codesigning

`extconf.rb` selects the identity in this order:

1. `SPEECH_MAC_CODESIGN_IDENTITY`
2. The SHA-1 hash of the first `Apple Development` line in `security find-identity -v -p codesigning` without a `CSSMERR_*` suffix. The hash is used instead of the name because revoked certificates share the name and make `codesign -s <name>` fail as ambiguous.
3. Ad hoc (`-`)

`codesign --force --identifier com.bash0c7.rb-speech-mac.helper --options runtime` binds the embedded `Info.plist`. TCC stores one Speech Recognition entry per identifier with the code requirement of the granted binary: a code hash for ad hoc, which a rebuild invalidates, or the designated requirement for an Apple Development signature, which survives rebuilds.

## Build flow

`bundle exec rake compile`, or `gem install` through `spec.extensions`:

1. `ruby extconf.rb` writes `ext/speech_mac/Makefile`
2. `xcrun swift build -c release --package-path . --product SpeechMacHelper`
3. `codesign` as above
4. `install -m 755` to `lib/speech_mac/SpeechMacHelper`

`bundle exec rake test` validates the RBS, compiles, and runs the tests.

## TDD discipline

t-wada style RED → GREEN → REFACTOR independent commits. test-unit. All tests run `test/fixtures/fake_helper.sh` in place of the helper, driven by `FAKE_EXIT`, `FAKE_STDOUT`, `FAKE_STDERR`, and `FAKE_SIGNAL`. `test/fixtures/sample.aiff` is English speech generated with `say -v Samantha`; run the real helper against it to check recognition.

## Related projects

- `~/dev/src/github.com/bash0C7/swift_gem` — scaffold origin
- `~/dev/src/github.com/bash0C7/rb-translation-mac` — sibling with the same helper subprocess layout
- `~/dev/src/github.com/bash0C7/rb-vision-mac` — sibling on the C extension scaffold

## Environment requirements

macOS 27+, Apple Silicon, Xcode 27 (Swift 6.4, builds run `xcrun swift`), Ruby 4.0+, bundler 4.x, rbs 4.x. Siri or Dictation must be enabled (System Settings → Apple Intelligence & Siri, or Keyboard → Dictation); on-device recognition uses their language model. An Apple Development identity in the keychain keeps the Speech Recognition grant across rebuilds. `Gemfile.lock` is not git-tracked.

## Prohibitions

- No Python source
- No code comments. Swift is documented with DocC (`///`, `- Parameter`, `- Returns`, ``` ``symbol`` ``` links); Ruby is documented with `#` comments above declarations in `sig/speech_mac.rbs`. History goes in commit messages
- Do not git-track `Gemfile.lock`
- Do not add live microphone capture (AVAudioEngine); file-based only
- Do not promise thread safety for concurrent calls
- Do not cache, normalize, or post-process transcription results
- Do not call `SFSpeechRecognizer.requestAuthorization` outside the helper subprocess; the Ruby interpreter has no `NSSpeechRecognitionUsageDescription` and TCC would kill it
- Commit messages in English, conventional commits style
- `.claude/` is committed
