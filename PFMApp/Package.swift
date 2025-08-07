// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PFMApp",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PFMApp",
            targets: ["PFMApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Liquid4All/leap-ios.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "PFMApp",
            dependencies: [
                .product(name: "LeapSDK", package: "leap-ios")
            ]),
        .testTarget(
            name: "PFMAppTests",
            dependencies: ["PFMApp"]),
    ]
)