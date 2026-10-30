import Foundation
import Darwin

private typealias DisclaimFn = @convention(c) (
    UnsafeMutablePointer<posix_spawnattr_t?>, Int32
) -> Int32

/// The environment variable that marks the re-executed helper process.
let disclaimEnvKey = "SPEECH_MAC_HELPER_DISCLAIMED"

/// Re-executes the helper with TCC responsibility disclaimed and exits with the child's status.
///
/// TCC attributes Speech Recognition consent to the responsible process, which is the terminal or Ruby host
/// unless disclaimed. The re-executed child is responsible for itself, so TCC reads the helper's embedded
/// `Info.plist`. The child carries ``disclaimEnvKey`` so it does not re-execute again. A child killed by a
/// signal is mirrored by killing this process with the same signal.
func reexecWithDisclaim() -> Never {
    guard let sym = dlsym(dlopen(nil, RTLD_NOW), "responsibility_spawnattrs_setdisclaim") else {
        warn("responsibility_spawnattrs_setdisclaim unavailable")
        exit(1)
    }
    let setDisclaim = unsafeBitCast(sym, to: DisclaimFn.self)

    var attrs: posix_spawnattr_t?
    guard posix_spawnattr_init(&attrs) == 0 else {
        warn("posix_spawnattr_init failed")
        exit(1)
    }
    defer { posix_spawnattr_destroy(&attrs) }

    guard setDisclaim(&attrs, 1) == 0 else {
        warn("responsibility_spawnattrs_setdisclaim failed")
        exit(1)
    }

    var argv: [UnsafeMutablePointer<CChar>?] = CommandLine.arguments.map { strdup($0) }
    argv.append(nil)
    defer { argv.forEach { free($0) } }

    var env = ProcessInfo.processInfo.environment
    env[disclaimEnvKey] = "1"
    var envp: [UnsafeMutablePointer<CChar>?] = env.map { strdup("\($0)=\($1)") }
    envp.append(nil)
    defer { envp.forEach { free($0) } }

    var pid: pid_t = 0
    let rc = posix_spawn(&pid, CommandLine.arguments[0], nil, &attrs, argv, envp)
    if rc != 0 {
        warn("posix_spawn failed: \(rc)")
        exit(1)
    }

    var status: Int32 = 0
    waitpid(pid, &status, 0)

    let sig = status & 0x7f
    if sig != 0 {
        signal(sig, SIG_DFL)
        kill(getpid(), sig)
        exit(128 + sig)
    }
    exit((status >> 8) & 0xff)
}
