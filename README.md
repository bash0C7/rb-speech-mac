# rb-speech-mac

Ruby binding for Apple's Speech framework on macOS / Apple Silicon. Transcribes audio files on device with `SFSpeechURLRecognitionRequest` through the bundled `SpeechMacHelper` subprocess, a Swift Package Manager executable that embeds `NSSpeechRecognitionUsageDescription` in its Mach-O so macOS can grant it Speech Recognition permission.

## Requirements

- macOS 27+, Apple Silicon
- Xcode 27 (builds run `xcrun swift`)
- Ruby 4.0+, Bundler 4.x
- Siri or Dictation enabled: **System Settings → Apple Intelligence & Siri**, or **System Settings → Keyboard → Dictation**. On-device recognition uses their language model; with both off, `transcribe` fails with `SpeechMac::Error`.

## Installation

Install from source:

```bash
git clone https://github.com/bash0C7/rb-speech-mac.git
cd rb-speech-mac
bundle install
bundle exec rake compile
```

`rake compile` builds `SpeechMacHelper` with `xcrun swift build -c release --package-path ext/speech_mac --product SpeechMacHelper`, signs it, and installs it to `lib/speech_mac/SpeechMacHelper`. Installing the packaged gem runs the same build through `ext/speech_mac/extconf.rb`.

## Usage

```ruby
require "speech_mac"

auth = SpeechMac.authorize
exit unless auth.success

result = SpeechMac.transcribe("path/to/audio.aiff")
if result.success
  puts result.text
else
  warn "#{result.error.class}: #{result.error.message}"
end
```

`authorize` shows the macOS Speech Recognition permission dialog while the status is not determined and returns a `SpeechMac::AuthorizationResult` with `status` (`:authorized`, `:denied`, `:restricted`, `:not_determined`, or `:unknown`), `success`, and `error`. `error` is `SpeechMac::TimeoutError` when the dialog gets no answer within 60 seconds and `SpeechMac::NotAuthorizedError` for any other status than `:authorized`.

`transcribe` returns a `SpeechMac::Result` with `text`, `success`, and `error`. It reads the granted permission and never shows the dialog. Locale is `en-US`, recognition runs on device only, and the time limit is 30 seconds. A missing audio path raises `Errno::ENOENT`; every other failure sets `error` to one of:

| Error | Cause |
|---|---|
| `SpeechMac::NotAuthorizedError` | Speech Recognition permission is not granted |
| `SpeechMac::RecognizerUnavailableError` | The `en-US` recognizer or its on-device model is unavailable |
| `SpeechMac::FileNotFoundError` | The helper could not find the audio file |
| `SpeechMac::TimeoutError` | Recognition did not finish within 30 seconds |
| `SpeechMac::Error` | The Speech framework reported an error; `message` carries it |
| `SpeechMac::HelperSpawnError` | The helper binary is missing or not executable |
| `SpeechMac::HelperCrashError` | The helper was killed by a signal or exited unexpectedly |

`SpeechMac.helper_path=` points the gem at another helper binary.

## Codesigning

The build signs the helper with, in order of preference:

1. `SPEECH_MAC_CODESIGN_IDENTITY`
2. The SHA-1 hash of the first unrevoked `Apple Development` identity in `security find-identity -v -p codesigning`
3. Ad hoc (`-`)

macOS keeps the Speech Recognition grant for an Apple Development signature across rebuilds. An ad hoc signature is identified by its code hash, so each rebuild that changes the binary asks for permission again.

```bash
SPEECH_MAC_CODESIGN_IDENTITY=- bundle exec rake compile
```

## Examples

```bash
bundle exec ruby example.rb [path/to/audio.aiff]
```

`example.rb` calls `SpeechMac.authorize`, then transcribes the given file or `test/fixtures/sample.aiff`.

```bash
xcrun swift examples/speech_mac.swift path/to/audio.aiff
```

`examples/speech_mac.swift` calls Speech directly from a Swift script. It only reads the authorization status of its host process, which has no Speech Recognition grant, so it exits with status 2 unless that host has been granted permission.

## Development

```bash
bundle install
bundle exec rake test
bundle exec rake console
```

`rake test` validates `sig/speech_mac.rbs`, runs `rake compile`, then runs the tests. The tests run `test/fixtures/fake_helper.sh` in place of the helper, driven by `FAKE_EXIT`, `FAKE_STDOUT`, `FAKE_STDERR`, and `FAKE_SIGNAL`.

## License

MIT.
