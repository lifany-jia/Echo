// swift-tools-version: 6.0

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "EchoForest",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .iOSApplication(
            name: "EchoForest",
            targets: ["AppModule"],
            bundleIdentifier: "com.echoforest.playground",
            teamIdentifier: nil,
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .leaf),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            additionalInfoPlistContentFilePath: "Info.plist"
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ],
    swiftLanguageVersions: [.v6]
)
