// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sign_in_with_apple",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "sign-in-with-apple", targets: ["sign_in_with_apple"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "sign_in_with_apple",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
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
