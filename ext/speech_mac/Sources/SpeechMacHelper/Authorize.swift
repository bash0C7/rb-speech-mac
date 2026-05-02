import Speech
import Foundation

private let authorizeTimeoutSeconds = 60

func authorize() -> Int32 {
    let initial = SFSpeechRecognizer.authorizationStatus()
    FileHandle.standardError.write("[diag] authorize: initial status=\(initial.rawValue)\n".data(using: .utf8)!)

    // Short-circuit if already decided — no callback needed, no dialog
    if initial != .notDetermined {
        return emit(status: initial)
    }

    var finalStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    FileHandle.standardError.write("[diag] authorize: calling requestAuthorization, will spin main runloop\n".data(using: .utf8)!)

    SFSpeechRecognizer.requestAuthorization { status in
        FileHandle.standardError.write("[diag] authorize: callback fired status=\(status.rawValue)\n".data(using: .utf8)!)
        finalStatus = status
        CFRunLoopStop(CFRunLoopGetMain())
    }

    // Bound the wait via a one-shot timer that stops the runloop.
    var timedOut = false
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + .seconds(authorizeTimeoutSeconds))
    timer.setEventHandler {
        timedOut = true
        FileHandle.standardError.write("[diag] authorize: timeout fired\n".data(using: .utf8)!)
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
