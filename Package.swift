// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "calendar-bridge",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git",
                 from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "calendar-bridge",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/calendar-bridge/Info.plist"
                ], .when(platforms: [.macOS]))
            ]
        )
    ]
)
