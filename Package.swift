// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MetalVoice",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MetalVoice", targets: ["MetalVoice"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MetalVoice",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("../Resources")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreML"),
                .linkedFramework("Accelerate")
            ]
        )
    ]
)
