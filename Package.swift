// swift-tools-version: 6.0
//
// Package layout:
//
//   ExifCheckerCore  - A pure library target that contains everything needed
//                      to read metadata: data models, value formatters, the
//                      field description database, and the ImageIO /
//                      AVFoundation based extractors. It has no UI
//                      dependencies so it can be unit tested headlessly.
//
//   ExifChecker      - The actual macOS application (SwiftUI) plus a small
//                      command line dump mode (`--dump <file>`), inspired by
//                      the CLI tools `exiftool` and `ffprobe`.
//
//   ExifCheckerCoreTests - XCTest suite for the core target.

import PackageDescription

let package = Package(
    name: "ExifChecker",
    platforms: [
        // macOS 14 gives us the modern async AVFoundation loading APIs
        // (AVAsset.load(.tracks) etc.) and mature SwiftUI Table/List support.
        .macOS(.v14)
    ],
    targets: [
        // MARK: Core library (no AppKit/SwiftUI imports on purpose)
        .target(
            name: "ExifCheckerCore",
            path: "Sources/ExifCheckerCore"
        ),
        // MARK: macOS application executable
        .executableTarget(
            name: "ExifChecker",
            dependencies: ["ExifCheckerCore"],
            path: "Sources/ExifChecker"
        ),
        // MARK: Unit tests for the core library
        .testTarget(
            name: "ExifCheckerCoreTests",
            dependencies: ["ExifCheckerCore"],
            path: "Tests/ExifCheckerCoreTests"
        )
    ]
)
