import Foundation

if ProcessInfo.processInfo.environment[disclaimEnvKey] == nil {
    reexecWithDisclaim()
}

let arguments = CommandLine.arguments

guard arguments.count >= 2 else {
    warn("usage: SpeechMacHelper <transcribe|authorize> [args...]")
    exit(1)
}

switch arguments[1] {
case "transcribe":
    guard arguments.count >= 3 else {
        warn("usage: SpeechMacHelper transcribe <audio-path>")
        exit(1)
    }
    exit(transcribe(path: arguments[2]))
case "authorize":
    exit(authorize())
default:
    warn("unknown subcommand: \(arguments[1])")
    exit(1)
}
