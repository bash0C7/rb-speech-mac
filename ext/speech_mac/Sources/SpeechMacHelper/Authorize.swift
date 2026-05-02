import Speech
import Foundation

func authorize() -> Int32 {
    let sem = DispatchSemaphore(value: 0)
    var finalStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    SFSpeechRecognizer.requestAuthorization { status in
        finalStatus = status
        sem.signal()
    }
    sem.wait()

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
