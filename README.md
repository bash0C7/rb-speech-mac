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

Speech Recognition permission must be granted to the calling process (Ruby / Terminal / iTerm) via System Settings → Privacy & Security → Speech Recognition. The first call triggers an authorization request; if denied or undetermined, `transcribe` returns `""`.

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
