import Foundation

@_cdecl("speech_mac_transcribe")
public func speech_mac_transcribe(_ path: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar> {
    let s = String(cString: path)
    return strdup(performTranscribe(path: s))!
}

@_cdecl("speech_mac_free")
public func speech_mac_free(_ ptr: UnsafeMutablePointer<CChar>?) {
    free(ptr)
}
