// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sign_in_with_apple",
    platforms: [
        .macOS("10.15"),
    ],
    products: [
        .library(name: "sign-in-with-apple", targets: ["sign_in_with_apple"]),
    ],
    dependencies: [
        .package(name: "FlutterMacOSFramework", path: "../FlutterMacOSFramework"),
    ],
    targets: [
        .target(
            name: "sign_in_with_apple",
            dependencies: [
                .product(name: "FlutterMacOSFramework", package: "FlutterMacOSFramework"),
            ],
            path: "..",
            exclude: [
                "sign_in_with_apple.podspec",
            ],
            sources: [
                "Classes",
            ],
            publicHeadersPath: "Classes"
        ),
    ]
)
