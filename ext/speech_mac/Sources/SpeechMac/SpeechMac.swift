import Speech
import Foundation

private let recognitionTimeoutSeconds: Int = 30
private let defaultLocale = "en-US"

func performTranscribe(path: String) -> String {
    if path.isEmpty { return "" }
    if !FileManager.default.fileExists(atPath: path) { return "" }

    // Do NOT call SFSpeechRecognizer.requestAuthorization from a host process
    // without NSSpeechRecognitionUsageDescription in its Info.plist — TCC
    // hard-crashes the process (TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION).
    // We only read the cached status. If the host (typically the Ruby
    // interpreter running this dylib) has never been authorized, return "".
    if SFSpeechRecognizer.authorizationStatus() != .authorized { return "" }

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: defaultLocale)),
          recognizer.isAvailable else {
        return ""
    }

    let url = URL(fileURLWithPath: path)
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false

    var transcription = ""
    let sem = DispatchSemaphore(value: 0)
    var signaled = false

    recognizer.recognitionTask(with: request) { result, error in
        if let result = result, result.isFinal {
            transcription = result.bestTranscription.formattedString
            if !signaled { signaled = true; sem.signal() }
        } else if error != nil {
            if !signaled { signaled = true; sem.signal() }
        }
    }

    if sem.wait(timeout: .now() + .seconds(recognitionTimeoutSeconds)) == .timedOut {
        return ""
    }
    return transcription
}
