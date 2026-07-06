// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AtomObjects",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "AtomObjects",
            targets: ["AtomObjects"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "AtomObjects",
            dependencies: [],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]),
        .testTarget(
            name: "AtomObjectsTests",
            dependencies: ["AtomObjects", .product(name: "Testing", package: "swift-testing")]),
    ],
    swiftLanguageModes: [.v6]
)
