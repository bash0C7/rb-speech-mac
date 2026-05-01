# CLAUDE.md — rb-speech-mac

## Position

Ruby native binding for Apple's Speech framework on macOS. Sibling of `rb-vision-ocrmac`, built on the same `bash0C7/swift_gem` scaffold. Exposes file-based speech transcription (no live microphone capture) as a singleton method on `SpeechMac`.

## Core design principles

1. Thin wrapper. Pass-through Speech API. One audio file → one transcribed string.
2. Fixed defaults: locale `en-US`, `shouldReportPartialResults = false`. Changes go through new API methods; never break existing behavior.
3. 30s overall timeout, 5s authorization-request timeout. Failure (no permission, unreadable file, recognizer unavailable, OS error) → empty string. Does not raise exceptions.
4. C bridge string handoff. Single `@_cdecl` pair plus shared `speech_mac_free`. Bridge function signatures fixed at `UnsafePointer<CChar>` ↔ `UnsafeMutablePointer<CChar>`.
5. Scaffold parity. `swift_gem new rb-speech-mac` produces a skeleton whose only diffs against this repo are the implementation body, fixtures, and build artifacts.

## Public API

| Method | Returns | Notes |
|---|---|---|
| `SpeechMac.transcribe(path)` | best-transcription string | `SFSpeechURLRecognitionRequest`, `en-US`. Empty string if not authorized, recognizer unavailable, file missing, or timeout |

## Known limitations

**Permission handling on CLI / dylib loading.** Speech framework on macOS requires Speech Recognition permission. The first call to `SpeechMac.transcribe` triggers `SFSpeechRecognizer.requestAuthorization`. Behavior depends on the host process:
- The dylib is loaded into the Ruby interpreter, which has no `NSSpeechRecognitionUsageDescription` Info.plist key — auto-deny is possible.
- If denied or undetermined, `transcribe` returns `""`.
- The user may need to grant Speech Recognition permission to the calling process (Ruby / Terminal / iTerm) via System Settings → Privacy & Security → Speech Recognition.

Tests therefore assert only return type (`String`) and the empty-string fallback path, not specific transcribed content.

## Architecture

```
[caller (Ruby)]
  │
  │   SpeechMac.transcribe(path) → String
  ▼
lib/speech_mac.rb            ← requires the ext + module declaration
  │
  ▼
ext/speech_mac/speech_mac.c   ← rb_define_singleton_method
  │
  │   speech_mac_transcribe(c_path)
  ▼
ext/speech_mac/Sources/SpeechMac/SpeechMacBridge.swift   ← @_cdecl
  │
  ▼
ext/speech_mac/Sources/SpeechMac/SpeechMac.swift   ← SFSpeechRecognizer + SFSpeechURLRecognitionRequest
  │
  ▼
[Apple Speech framework]
```

## Module boundaries

| Layer | Responsibility |
|---|---|
| `lib/speech_mac.rb` | `require_relative` to load the .bundle; host of `module SpeechMac` |
| `ext/speech_mac/speech_mac.c` | `Init_speech_mac` exposes `transcribe`; copies Swift-returned `char*` into a Ruby UTF-8 String, then calls `speech_mac_free` |
| `SpeechMacBridge.swift` | C ABI export via `@_cdecl`. Calls Swift implementation and returns C string via `strdup` |
| `SpeechMac.swift` | Real implementation: synchronous `SFSpeechRecognizer.requestAuthorization` + `SFSpeechURLRecognitionRequest`. `DispatchSemaphore` for both auth and recognition timeouts |
| `ext/speech_mac/extconf.rb` | `SwiftGem::Mkmf.create_swift_makefile("speech_mac/speech_mac", package: "SpeechMac", source_dir: __dir__)` |
| `examples/speech_mac.swift` | Pure-Swift sample script. Ruby-free, kept as a Speech-behavior reference |
| `Rakefile` | `Rake::ExtensionTask("speech_mac")` + `task test: :compile`. `task console: :compile` for IRB |

## Build flow

`bundle exec rake test` in one shot — same as `rb-vision-ocrmac`.

## TDD discipline

t-wada style RED → GREEN → REFACTOR independent commits. test-unit. Fixture: `test/fixtures/sample.aiff` generated via macOS `say -v Samantha` and committed (~135 KB).

## Related projects

- `~/dev/src/github.com/bash0C7/swift_gem` — scaffold/Mkmf framework
- `~/dev/src/github.com/bash0C7/rb-vision-ocrmac` — sibling reference implementation
- `~/dev/src/github.com/bash0C7/rb-record-transcribe-mac` — different stack (FFmpeg + MLX Whisper); kept as a non-Speech-framework alternative

## Environment requirements

macOS 12+, Apple Silicon, Swift 6.0+, Ruby 3.2+, bundler 4.x, rake-compiler 1.2+. `Gemfile` references swift_gem via `path: "../swift_gem"` until publish. `Gemfile.lock` not git-tracked.

Speech Recognition permission must be granted to the calling process. `say` available (default on macOS) for fixture regeneration.

## Prohibitions

- No Python source
- Do not git-track `Gemfile.lock`
- Do not add live microphone capture (AVAudioEngine) here — file-based only. Live capture is a separate concern
- Do not promise thread safety for concurrent calls
- Do not cache, normalize, or post-process transcription results here
- Commit messages in English, conventional commits style
- `.claude/` is committed
