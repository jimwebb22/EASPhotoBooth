// swift-tools-version: 5.9
// Package.swift — EtchBot
// Used for Swift Package Manager compatibility and running unit tests
// without a full Xcode project (Linux CI / macOS command-line).
//
// NOTE: The full iOS app requires Xcode 15+ and iOS 17 deployment target.
// The image-processing logic (no UIKit/AVFoundation deps) is testable here.

import PackageDescription

let package = Package(
    name: "EtchBot",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EtchBotCore",
            targets: ["EtchBotCore"]
        )
    ],
    targets: [
        // Core logic library (no UIKit / AVFoundation dependency)
        // Used for testing the algorithm pipeline.
        .target(
            name: "EtchBotCore",
            path: "EtchBot",
            exclude: [
                "App",
                "Views",
                "ViewModels",
                "Services/Bluetooth",
                "Resources"
            ],
            sources: [
                "Models",
                "Services/ImageProcessing",
                "Services/Persistence",
                "Utilities"
            ]
        ),
        // Unit test target
        .testTarget(
            name: "EtchBotTests",
            dependencies: ["EtchBotCore"],
            path: "EtchBotTests"
        )
    ]
)
