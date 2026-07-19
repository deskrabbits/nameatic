// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Renamatic",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: [
        .executableTarget(
            name: "Renamatic",
            dependencies: ["Sparkle"],
            path: "Sources/Renamatic",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
