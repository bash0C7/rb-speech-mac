# rb-speech-mac

Ruby binding for Apple's Speech framework on macOS / Apple Silicon. Calls file-based speech recognition (`SFSpeechURLRecognitionRequest`) directly from Ruby via Swift Package Manager and a thin C bridge. Built on [swift_gem](https://github.com/bash0C7/swift_gem).

## Installation

```bash
bundle add rb-speech-mac
```

```bash
gem install rb-speech-mac
```

## Usage

```ruby
require "speech_mac"

SpeechMac.transcribe("path/to/audio.aiff")
# => "Hello world this is a test of speech recognition"
```

Locale is fixed at `en-US`. On failure (no Speech Recognition permission, unreadable file, recognizer unavailable, 30s timeout) the method returns `""`.

Or open an IRB console with the gem preloaded:

```bash
bundle exec rake console
```

## Permission

Speech.framework requires `NSSpeechRecognitionUsageDescription` in the host process's Info.plist. Calling `SFSpeechRecognizer.requestAuthorization()` without that key would hard-crash the process via TCC. This gem therefore only reads `SFSpeechRecognizer.authorizationStatus()` and returns `""` if not already `.authorized`. In a CLI Ruby session that status will be `.notDetermined` and `transcribe` will return `""`. To get a real transcription, run from a host process that already has the proper Info.plist (e.g. an app bundle). See `CLAUDE.md` for the full rationale.

## Reference: Ruby example

`example.rb` at the repo root demonstrates the call:

```bash
bundle exec ruby example.rb path/to/audio.aiff
```

It defaults to `test/fixtures/sample.aiff` (generated via `say -v Samantha`) if no argument is given.

## Reference: pure Swift sample

A self-contained Swift script lives at `examples/speech_mac.swift` for sanity-checking Speech behavior without going through Ruby:

```bash
swift examples/speech_mac.swift path/to/audio.aiff
```

## Development

```bash
bundle install
bundle exec rake test
```

`rake test` automatically compiles the Swift Package (`swift build -c release`) and links the C bridge into `lib/speech_mac/speech_mac.bundle` before running the spec, via `Rake::ExtensionTask`.

To run only the build step: `bundle exec rake compile`.

## License

MIT.
