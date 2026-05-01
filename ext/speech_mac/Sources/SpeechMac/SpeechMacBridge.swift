import Foundation

@_cdecl("speech_mac_perform")
public func speech_mac_perform(_ input: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar> {
    let s = String(cString: input)
    let result = speech_mac_perform(s)
    return strdup(result)!
}

@_cdecl("speech_mac_free")
public func speech_mac_free(_ ptr: UnsafeMutablePointer<CChar>?) {
    free(ptr)
}
