// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpeechMacHelper",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "SpeechMacHelper",
            path: "Sources/SpeechMacHelper",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist"
                ])
            ]
        ),
    ]
)
