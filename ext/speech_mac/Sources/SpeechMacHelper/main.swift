import Foundation

// Disclaim TCC responsibility from the parent (terminal / Ruby) once, on
// first invocation. See Disclaim.swift for the why.
if ProcessInfo.processInfo.environment[disclaimEnvKey] == nil {
    reexecWithDisclaim()
}

let arguments = CommandLine.arguments

guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: SpeechMacHelper <transcribe|authorize> [args...]\n".data(using: .utf8)!)
    exit(1)
}

let subcommand = arguments[1]
let rest = Array(arguments.dropFirst(2))

switch subcommand {
case "transcribe":
    guard let path = rest.first else {
        FileHandle.standardError.write("usage: SpeechMacHelper transcribe <audio-path>\n".data(using: .utf8)!)
        exit(1)
    }
    exit(transcribe(path: path))
case "authorize":
    exit(authorize())
default:
    FileHandle.standardError.write("unknown subcommand: \(subcommand)\n".data(using: .utf8)!)
    exit(1)
}
