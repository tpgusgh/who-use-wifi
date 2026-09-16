// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhoUseWifi",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WhoUseWifi",
            path: "Sources/WhoUseWifi",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "WhoUseWifiTests",
            dependencies: ["WhoUseWifi"],
            path: "Tests/WhoUseWifiTests"
        )
    ]
)
