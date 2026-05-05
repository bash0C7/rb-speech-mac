# rb-speech-mac

Ruby binding for Apple's Speech framework on macOS / Apple Silicon. Wraps `SFSpeechURLRecognitionRequest` for file-based transcription.

This gem solves the TCC privacy-violation crash that normally kills Ruby when calling Speech.framework: it ships a small Swift CLI helper that's built and signed at install time, with `NSSpeechRecognitionUsageDescription` embedded into its Mach-O. Ruby spawns the helper as a subprocess and reads the result.

## Installation

```bash
bundle add rb-speech-mac
```

```bash
gem install rb-speech-mac
```

The helper binary is built and signed during `gem install` (no precompiled binaries are shipped). Requires Swift 6.0+ and macOS 12+. Optional but recommended: an Apple Development signing identity in your keychain for stable TCC permission across rebuilds — without it, the helper falls back to ad-hoc signing and macOS will re-prompt for Speech Recognition permission after each rebuild.

## System requirements: enable Siri (or Dictation)

Recognition runs on-device. The on-device language model that `SFSpeechRecognizer` uses ships with **Siri** and **Dictation** — the system requires at least one of those to be turned on. With both off, the framework returns `kLSRErrorDomain Code=201 "Siri and Dictation are disabled"` and `transcribe` fails with a generic `SpeechMac::Error` carrying that message.

On macOS 15 (Sequoia) and later, enable Siri from:

> **System Settings → Apple Intelligence & Siri → Siri**

(Older macOS: **System Settings → Siri & Spotlight** or **Keyboard → Dictation**.)

The first time you transcribe, macOS may also show a one-time notice that audio data may be sent to Apple to improve recognition. Click through it; the gem sets `requiresOnDeviceRecognition = true`, so audio stays on the device regardless.

## Usage

```ruby
require "speech_mac"

# Trigger the macOS permission dialog (only needed once per machine, per binary).
auth = SpeechMac.authorize
exit unless auth.success # auth.error tells you why

result = SpeechMac.transcribe("path/to/audio.aiff")
if result.success
  puts result.text
else
  warn "#{result.error.class}: #{result.error.message}"
end
```

`SpeechMac.transcribe` returns a `SpeechMac::Result` Data with `.text` (String or nil), `.success` (Boolean), and `.error` (an Exception subclass instance or nil). `SpeechMac.authorize` returns `SpeechMac::AuthorizationResult` with `.status` symbol, `.success`, `.error`.

**Missing audio path raises `Errno::ENOENT`** before the helper is invoked; this is a precondition violation, not a domain error, so it bypasses `Result`. Domain failures the caller is expected to handle (TCC denied, Siri off, recognizer unavailable, 30s timeout, Apple-framework recognition error, file exists but unreadable) flow through `result.error` as before.

Locale is fixed at `en-US`. Recognition runs on-device only and has a 30s timeout.

## Codesigning

`extconf.rb` selects an identity in this order:

1. `SPEECH_MAC_CODESIGN_IDENTITY` env var
2. First `Apple Development:` certificate from `security find-identity -v -p codesigning`
3. Ad-hoc (`-`) fallback

Pass an explicit identity if you want stable TCC permission across rebuilds:

```bash
SPEECH_MAC_CODESIGN_IDENTITY="Apple Development: Foo (XXXX)" bundle install
```

## Reference: Ruby example

```bash
bundle exec ruby example.rb path/to/audio.aiff
```

Defaults to `test/fixtures/sample.aiff` (generated via `say -v Samantha`) if no argument is given. Calls `SpeechMac.authorize` then `SpeechMac.transcribe`.

## Reference: pure Swift sample

A standalone Swift script at `examples/speech_mac.swift` for sanity-checking Speech behavior without going through Ruby:

```bash
xcrun swift examples/speech_mac.swift path/to/audio.aiff
```

Use `xcrun swift` (Xcode toolchain — install via `xcode-select --install`), not bare `swift` from swiftly. swiftly's swift interpret mode does not JIT-link Apple system frameworks (Speech) and aborts at startup with symbol-resolution errors; xcrun's swift uses dyld and works as-is. The library build itself does not need Xcode CLT — this is sample-only.

Note: this script will get the same `.notDetermined` status as an unsigned Ruby interpreter would and will not actually transcribe — it's a behavioral reference, not a working alternative.

## Development

```bash
bundle install
bundle exec rake compile  # builds the helper and installs it under lib/
bundle exec rake test     # runs the spec suite (uses a fake helper, no real binary needed)
```

## License

MIT.
