import Speech
import Foundation

private let recognitionTimeoutSeconds = 30
private let defaultLocale = "en-US"

func transcribe(path: String) -> Int32 {
    if path.isEmpty {
        FileHandle.standardError.write("audio path is empty\n".data(using: .utf8)!)
        return 4
    }
    if !FileManager.default.fileExists(atPath: path) {
        FileHandle.standardError.write("audio file not found: \(path)\n".data(using: .utf8)!)
        return 4
    }

    if SFSpeechRecognizer.authorizationStatus() != .authorized {
        FileHandle.standardError.write("speech recognition not authorized; run `authorize` subcommand first\n".data(using: .utf8)!)
        return 2
    }

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: defaultLocale)),
          recognizer.isAvailable else {
        FileHandle.standardError.write("recognizer unavailable for locale \(defaultLocale)\n".data(using: .utf8)!)
        return 3
    }

    guard recognizer.supportsOnDeviceRecognition else {
        FileHandle.standardError.write("on-device recognition not supported for locale \(defaultLocale); enable Siri or Dictation in System Settings and install the language model\n".data(using: .utf8)!)
        return 3
    }

    let url = URL(fileURLWithPath: path)
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false
    request.taskHint = .dictation
    request.requiresOnDeviceRecognition = true

    var transcription = ""
    var recognitionError: Error? = nil
    var done = false

    recognizer.recognitionTask(with: request) { result, error in
        if let error = error {
            recognitionError = error
            done = true
            CFRunLoopStop(CFRunLoopGetMain())
            return
        }
        if let result = result, result.isFinal {
            transcription = result.bestTranscription.formattedString
            done = true
            CFRunLoopStop(CFRunLoopGetMain())
        }
    }

    // SFSpeechRecognizer dispatches result callbacks through the main run loop.
    // CFRunLoopRun lets them execute; the one-shot timer bounds the wait.
    var timedOut = false
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + .seconds(recognitionTimeoutSeconds))
    timer.setEventHandler {
        timedOut = true
        CFRunLoopStop(CFRunLoopGetMain())
    }
    timer.resume()

    CFRunLoopRun()
    timer.cancel()

    if timedOut && !done {
        FileHandle.standardError.write("recognition timed out after \(recognitionTimeoutSeconds)s\n".data(using: .utf8)!)
        return 5
    }
    if let error = recognitionError {
        FileHandle.standardError.write("recognition error: \(error.localizedDescription)\n".data(using: .utf8)!)
        return 6
    }

    print(transcription, terminator: "")
    return 0
}
