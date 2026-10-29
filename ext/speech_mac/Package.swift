// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SpeechMac",
    platforms: [.macOS(.v27)],
    products: [
        .executable(
            name: "SpeechMacHelper",
            targets: ["SpeechMacHelper"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "SpeechMacHelper",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist",
                ])
            ]
        ),
    ]
)
