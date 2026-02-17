// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AtomObjects",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
        .watchOS(.v7),
        .tvOS(.v14)
    ],
    products: [
        .library(
            name: "AtomObjects",
            targets: ["AtomObjects"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick", from: "4.0.0"),
        .package(url: "https://github.com/Quick/Nimble", from: "9.0.0"),
    ],
    targets: [
        .target(
            name: "AtomObjects",
            dependencies: []),
        .testTarget(
            name: "AtomObjectsTests",
            dependencies: ["AtomObjects", "Quick", "Nimble"]),
    ]
)
