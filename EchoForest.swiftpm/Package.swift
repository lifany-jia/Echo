// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EchoForest",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EchoForest", targets: ["EchoForest"])
    ],
    targets: [
        .executableTarget(
            name: "EchoForest",
            path: "Sources"
        )
    ]
)
