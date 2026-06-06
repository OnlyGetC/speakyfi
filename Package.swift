// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceToText",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceToText",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "SwiftWhisper", package: "SwiftWhisper"),
            ],
            path: "VoiceToText/Sources",
            resources: [
                .process("cat.jpeg"),
            ]
        ),
    ]
)
