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

Locale is fixed at `en-US`. Recognition has a 30s timeout.

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
swift examples/speech_mac.swift path/to/audio.aiff
```

Note: this script will get the same `.notDetermined` status as an unsigned Ruby interpreter would and will not actually transcribe — it's a behavioral reference, not a working alternative.

## Development

```bash
bundle install
bundle exec rake compile  # builds the helper and installs it under lib/
bundle exec rake test     # runs the spec suite (uses a fake helper, no real binary needed)
```

## License

MIT.
