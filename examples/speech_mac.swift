import Speech
import Foundation

guard let path = CommandLine.arguments.dropFirst().first else {
    FileHandle.standardError.write(Data("usage: xcrun swift examples/speech_mac.swift <audio-path>\n".utf8))
    exit(1)
}

let status = SFSpeechRecognizer.authorizationStatus()
guard status == .authorized else {
    FileHandle.standardError.write(Data("speech recognition not authorized for this host process (status=\(status.rawValue))\n".utf8))
    exit(2)
}

guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
    FileHandle.standardError.write(Data("recognizer unavailable\n".utf8))
    exit(3)
}

let request = SFSpeechURLRecognitionRequest(url: URL(filePath: path))
request.shouldReportPartialResults = false

recognizer.recognitionTask(with: request) { result, error in
    if let error {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        CFRunLoopStop(CFRunLoopGetMain())
    } else if let result, result.isFinal {
        print(result.bestTranscription.formattedString)
        CFRunLoopStop(CFRunLoopGetMain())
    }
}
_ = CFRunLoopRunInMode(.defaultMode, 30, false)
