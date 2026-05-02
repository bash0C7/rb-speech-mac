import Speech
import Foundation

private let authorizeTimeoutSeconds = 60

func authorize() -> Int32 {
    let sem = DispatchSemaphore(value: 0)
    var finalStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    SFSpeechRecognizer.requestAuthorization { status in
        finalStatus = status
        sem.signal()
    }
    if sem.wait(timeout: .now() + .seconds(authorizeTimeoutSeconds)) == .timedOut {
        FileHandle.standardError.write("authorize timed out after \(authorizeTimeoutSeconds)s (no user response)\n".data(using: .utf8)!)
        return 5
    }

    let statusName: String
    switch finalStatus {
    case .authorized:    statusName = "authorized"
    case .denied:        statusName = "denied"
    case .restricted:    statusName = "restricted"
    case .notDetermined: statusName = "notDetermined"
    @unknown default:    statusName = "unknown"
    }
    print(statusName, terminator: "")
    return finalStatus == .authorized ? 0 : 2
}
