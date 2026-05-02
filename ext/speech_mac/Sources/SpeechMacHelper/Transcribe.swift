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

    let url = URL(fileURLWithPath: path)
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false

    var transcription = ""
    var recognitionError: Error? = nil
    let sem = DispatchSemaphore(value: 0)

    recognizer.recognitionTask(with: request) { result, error in
        if let result = result, result.isFinal {
            transcription = result.bestTranscription.formattedString
            sem.signal()
        } else if let error = error {
            recognitionError = error
            sem.signal()
        }
    }

    if sem.wait(timeout: .now() + .seconds(recognitionTimeoutSeconds)) == .timedOut {
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
