import Foundation
import Darwin

// Private SPI from libsystem; declared via dlsym at runtime so the binary
// keeps working even on macOS versions where the symbol is renamed or absent.
//
// Why this exists:
// When SpeechMacHelper is launched from a Terminal/iTerm/cmux child process,
// macOS TCC attributes Speech Recognition consent against the *responsible*
// process — by default that is the terminal, not us. The terminal lacks
// NSSpeechRecognitionUsageDescription, so TCC kills us with SIGABRT
// (__TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION__). The fix is to re-exec
// ourselves once with responsibility disclaimed, so TCC sees the disclaimed
// grandchild's own identity (which has the right Info.plist embedded).

private typealias DisclaimFn = @convention(c) (
    UnsafeMutablePointer<posix_spawnattr_t?>, Int32
) -> Int32

let disclaimEnvKey = "SPEECH_MAC_HELPER_DISCLAIMED"

func reexecWithDisclaim() -> Never {
    let handle = dlopen(nil, RTLD_NOW)
    guard let sym = dlsym(handle, "responsibility_spawnattrs_setdisclaim") else {
        FileHandle.standardError.write("responsibility_spawnattrs_setdisclaim unavailable on this macOS\n".data(using: .utf8)!)
        exit(1)
    }
    let setDisclaim = unsafeBitCast(sym, to: DisclaimFn.self)

    var attrs: posix_spawnattr_t? = nil
    guard posix_spawnattr_init(&attrs) == 0 else {
        FileHandle.standardError.write("posix_spawnattr_init failed\n".data(using: .utf8)!)
        exit(1)
    }
    defer { posix_spawnattr_destroy(&attrs) }

    guard setDisclaim(&attrs, 1) == 0 else {
        FileHandle.standardError.write("responsibility_spawnattrs_setdisclaim failed\n".data(using: .utf8)!)
        exit(1)
    }

    let executablePath = CommandLine.arguments[0]
    var argv: [UnsafeMutablePointer<CChar>?] = CommandLine.arguments.map { strdup($0) }
    argv.append(nil)
    defer { argv.dropLast().forEach { if let p = $0 { free(p) } } }

    var env = ProcessInfo.processInfo.environment
    env[disclaimEnvKey] = "1"
    var envp: [UnsafeMutablePointer<CChar>?] = env.map { (k, v) in strdup("\(k)=\(v)") }
    envp.append(nil)
    defer { envp.dropLast().forEach { if let p = $0 { free(p) } } }

    var pid: pid_t = 0
    let rc = posix_spawn(&pid, executablePath, nil, &attrs, argv, envp)
    if rc != 0 {
        FileHandle.standardError.write("posix_spawn failed: \(rc)\n".data(using: .utf8)!)
        exit(1)
    }

    var status: Int32 = 0
    waitpid(pid, &status, 0)

    if (status & 0x7f) != 0 {
        // Child terminated by signal — propagate by re-raising so the caller
        // sees the same Process::Status semantics (exitstatus == nil + termsig).
        let sig = status & 0x7f
        signal(sig, SIG_DFL)
        kill(getpid(), sig)
        // Fallback in case kill returns
        exit(128 + sig)
    }
    exit((status >> 8) & 0xff)
}
