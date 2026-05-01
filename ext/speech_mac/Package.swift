// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpeechMac",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "SpeechMac",
            type: .dynamic,
            targets: ["SpeechMac"]
        ),
    ],
    targets: [
        .target(
            name: "SpeechMac"
        ),
    ]
)
