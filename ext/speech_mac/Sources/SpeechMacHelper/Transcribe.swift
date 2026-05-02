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

    let allowCloud = ProcessInfo.processInfo.environment["SPEECH_MAC_ALLOW_CLOUD"] == "1"

    if !allowCloud && !recognizer.supportsOnDeviceRecognition {
        FileHandle.standardError.write("on-device recognition not supported for locale \(defaultLocale); install the Siri language model in System Settings > Apple Intelligence & Siri (or set SPEECH_MAC_ALLOW_CLOUD=1)\n".data(using: .utf8)!)
        return 3
    }

    let url = URL(fileURLWithPath: path)
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false
    request.taskHint = .dictation
    request.requiresOnDeviceRecognition = !allowCloud

    var transcription = ""
    var recognitionError: Error? = nil
    var callbackCount = 0
    var done = false

    FileHandle.standardError.write("[diag] starting recognition: locale=\(defaultLocale) onDevice=\(!allowCloud) supportsOnDevice=\(recognizer.supportsOnDeviceRecognition) file=\(path)\n".data(using: .utf8)!)

    recognizer.recognitionTask(with: request) { result, error in
        callbackCount += 1
        if let error = error {
            FileHandle.standardError.write("[diag] callback #\(callbackCount): error=\(error.localizedDescription) (\(error))\n".data(using: .utf8)!)
            recognitionError = error
            done = true
            CFRunLoopStop(CFRunLoopGetMain())
            return
        }
        if let result = result {
            FileHandle.standardError.write("[diag] callback #\(callbackCount): isFinal=\(result.isFinal) text=\"\(result.bestTranscription.formattedString)\"\n".data(using: .utf8)!)
            if result.isFinal {
                transcription = result.bestTranscription.formattedString
                done = true
                CFRunLoopStop(CFRunLoopGetMain())
            }
        } else {
            FileHandle.standardError.write("[diag] callback #\(callbackCount): nil result, no error\n".data(using: .utf8)!)
        }
    }

    // Bound the wait via a one-shot timer; CFRunLoopStop is called from the
    // recognition callback (or the timer) to break the run.
    var timedOut = false
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + .seconds(recognitionTimeoutSeconds))
    timer.setEventHandler {
        timedOut = true
        FileHandle.standardError.write("[diag] transcribe: timeout fired (callbacks=\(callbackCount))\n".data(using: .utf8)!)
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
