import Speech
import Foundation

// Run with: xcrun swift examples/speech_mac.swift <audio-path>
//
// Use 'xcrun swift' (Xcode toolchain), not bare 'swift' (swiftly).
// swiftly's swift interpret mode fails to JIT-link Apple system frameworks
// (Speech), so symbol resolution errors at startup. xcrun's swift uses
// dyld for framework linking and works as expected.
//
// IMPORTANT: SFSpeechRecognizer.requestAuthorization() will hard-crash any
// host process that lacks NSSpeechRecognitionUsageDescription in its
// Info.plist (TCC privacy violation). The Swift CLI runtime has no such
// key, so this example only reads SFSpeechRecognizer.authorizationStatus().
// If the status is not .authorized, it exits without calling the framework.

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write("usage: xcrun swift examples/speech_mac.swift <audio-path>\n".data(using: .utf8)!)
    exit(1)
}

let path = CommandLine.arguments[1]

let status = SFSpeechRecognizer.authorizationStatus()
guard status == .authorized else {
    FileHandle.standardError.write("speech recognition not authorized for this host process (status=\(status.rawValue)); see CLAUDE.md\n".data(using: .utf8)!)
    exit(2)
}

guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
    FileHandle.standardError.write("recognizer unavailable\n".data(using: .utf8)!)
    exit(3)
}

let url = URL(fileURLWithPath: path)
let request = SFSpeechURLRecognitionRequest(url: url)
request.shouldReportPartialResults = false

let sem = DispatchSemaphore(value: 0)
recognizer.recognitionTask(with: request) { result, error in
    if let result = result, result.isFinal {
        print(result.bestTranscription.formattedString)
        sem.signal()
    } else if let error = error {
        FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
        sem.signal()
    }
}
_ = sem.wait(timeout: .now() + .seconds(30))
