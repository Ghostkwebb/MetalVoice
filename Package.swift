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
        .target(
            name: "Core",
            dependencies: [],
            path: "Sources/Core",
            resources: [
                .copy("../../Resources")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreML"),
                .linkedFramework("Accelerate")
            ]
        ),
        .executableTarget(
            name: "MetalVoice",
            dependencies: ["Core"],
            path: "Sources/App",
            resources: [
                .process("../../Resources")
            ]
        ),
        .executableTarget(
            name: "MetalVoiceCLI",
            dependencies: ["Core"],
            path: "Sources/CLI"
        )
    ]
)
