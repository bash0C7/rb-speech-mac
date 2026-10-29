import Speech
import Foundation

private let authorizeTimeoutSeconds = 60

/// Requests Speech Recognition permission and prints the resulting status name to standard output.
///
/// Shows the system permission dialog only while the status is `.notDetermined`.
///
/// - Returns: `0` when authorized, `2` for any other status, `5` when the dialog gets no answer within 60 seconds.
func authorize() -> Int32 {
    let initial = SFSpeechRecognizer.authorizationStatus()
    if initial != .notDetermined {
        return emit(status: initial)
    }

    var finalStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    SFSpeechRecognizer.requestAuthorization { status in
        finalStatus = status
        CFRunLoopStop(CFRunLoopGetMain())
    }

    if CFRunLoopRunInMode(.defaultMode, CFTimeInterval(authorizeTimeoutSeconds), false) == .timedOut {
        warn("authorize timed out after \(authorizeTimeoutSeconds)s (no user response)")
        return 5
    }
    return emit(status: finalStatus)
}

private func emit(status: SFSpeechRecognizerAuthorizationStatus) -> Int32 {
    let name = switch status {
    case .authorized: "authorized"
    case .denied: "denied"
    case .restricted: "restricted"
    case .notDetermined: "notDetermined"
    @unknown default: "unknown"
    }
    print(name, terminator: "")
    return status == .authorized ? 0 : 2
}
