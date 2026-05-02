import Speech
import Foundation

private let authorizeTimeoutSeconds = 60

func authorize() -> Int32 {
    // Short-circuit if already decided — no callback, no dialog
    let initial = SFSpeechRecognizer.authorizationStatus()
    if initial != .notDetermined {
        return emit(status: initial)
    }

    var finalStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    SFSpeechRecognizer.requestAuthorization { status in
        finalStatus = status
        CFRunLoopStop(CFRunLoopGetMain())
    }

    var timedOut = false
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + .seconds(authorizeTimeoutSeconds))
    timer.setEventHandler {
        timedOut = true
        CFRunLoopStop(CFRunLoopGetMain())
    }
    timer.resume()

    CFRunLoopRun()
    timer.cancel()

    if timedOut {
        FileHandle.standardError.write("authorize timed out after \(authorizeTimeoutSeconds)s (no user response)\n".data(using: .utf8)!)
        return 5
    }
    return emit(status: finalStatus)
}

private func emit(status: SFSpeechRecognizerAuthorizationStatus) -> Int32 {
    let statusName: String
    switch status {
    case .authorized:    statusName = "authorized"
    case .denied:        statusName = "denied"
    case .restricted:    statusName = "restricted"
    case .notDetermined: statusName = "notDetermined"
    @unknown default:    statusName = "unknown"
    }
    print(statusName, terminator: "")
    return status == .authorized ? 0 : 2
}
