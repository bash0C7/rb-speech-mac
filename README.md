# rb-speech-mac

Ruby binding for Apple's Speech framework on macOS. Wraps file-based speech recognition (`SFSpeechURLRecognitionRequest`) as a Ruby singleton method.

Built on top of [swift_gem](https://github.com/bash0C7/swift_gem). macOS / Apple Silicon only.

## Usage

```ruby
require "speech_mac"

SpeechMac.transcribe("path/to/audio.aiff")
# => "Hello world this is a test of speech recognition"
```

Locale is fixed at `en-US`. On failure (no Speech Recognition permission, unreadable file, recognizer unavailable, 30s timeout) the method returns `""`.

## Permission

Speech.framework requires `NSSpeechRecognitionUsageDescription` in the host process's Info.plist. Calling `SFSpeechRecognizer.requestAuthorization()` without that key would hard-crash the process via TCC. This gem therefore only reads `SFSpeechRecognizer.authorizationStatus()` and returns `""` if not already `.authorized`.

In a CLI Ruby session that status will be `.notDetermined` and `transcribe` will return `""`. To get a real transcription, run from a host process that already has the proper Info.plist (e.g. an app bundle).

## Reference Swift example

```bash
swift examples/speech_mac.swift path/to/audio.aiff
```

## Development

```bash
bundle install
bundle exec rake test
```

The test fixture `test/fixtures/sample.aiff` is generated with `say -v Samantha`.

## License

MIT.
