import Speech
import Foundation

private let recognitionTimeoutSeconds = 30
private let defaultLocale = "en-US"

/// Transcribes an audio file on device and prints the text to standard output.
///
/// Reads the cached authorization status and never shows the permission dialog; run ``authorize()`` first.
///
/// - Parameter path: The path of the audio file.
/// - Returns: `0` on success, `2` when not authorized, `3` when the `en-US` recognizer or its on-device model is unavailable, `4` when the file is missing, `5` on the 30-second timeout, `6` when Speech reports an error.
func transcribe(path: String) -> Int32 {
    if path.isEmpty {
        warn("audio path is empty")
        return 4
    }
    if !FileManager.default.fileExists(atPath: path) {
        warn("audio file not found: \(path)")
        return 4
    }

    if SFSpeechRecognizer.authorizationStatus() != .authorized {
        warn("speech recognition not authorized; run `authorize` subcommand first")
        return 2
    }

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: defaultLocale)),
          recognizer.isAvailable else {
        warn("recognizer unavailable for locale \(defaultLocale)")
        return 3
    }

    guard recognizer.supportsOnDeviceRecognition else {
        warn("on-device recognition not supported for locale \(defaultLocale); enable Siri or Dictation in System Settings and install the language model")
        return 3
    }

    let request = SFSpeechURLRecognitionRequest(url: URL(filePath: path))
    request.shouldReportPartialResults = false
    request.taskHint = .dictation
    request.requiresOnDeviceRecognition = true

    var transcription = ""
    var recognitionError: (any Error)?

    recognizer.recognitionTask(with: request) { result, error in
        if let error {
            recognitionError = error
            CFRunLoopStop(CFRunLoopGetMain())
        } else if let result, result.isFinal {
            transcription = result.bestTranscription.formattedString
            CFRunLoopStop(CFRunLoopGetMain())
        }
    }

    if CFRunLoopRunInMode(.defaultMode, CFTimeInterval(recognitionTimeoutSeconds), false) == .timedOut {
        warn("recognition timed out after \(recognitionTimeoutSeconds)s")
        return 5
    }
    if let recognitionError {
        warn("recognition error: \(recognitionError.localizedDescription)")
        return 6
    }

    print(transcription, terminator: "")
    return 0
}

/// Writes a message and a newline to standard error.
///
/// - Parameter message: The message to write.
func warn(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}
