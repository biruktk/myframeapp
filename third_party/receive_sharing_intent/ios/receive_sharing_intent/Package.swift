// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "receive_sharing_intent",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        .library(name: "receive-sharing-intent", targets: ["receive_sharing_intent"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "receive_sharing_intent",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "..",
            exclude: [
                "receive_sharing_intent.podspec",
            ],
            sources: [
                "Classes",
            ],
            publicHeadersPath: "Classes"
        ),
    ]
)
