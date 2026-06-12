// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "fluwx",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        .library(name: "fluwx", targets: ["fluwx"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "fluwx",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "..",
            exclude: [
                "fluwx.podspec",
                "wechat_setup.rb",
            ],
            sources: [
                "Classes",
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: "Classes/public",
            cSettings: [
                .define("WECHAT_LOGGING", to: "0"),
                .headerSearchPath("Classes"),
                .headerSearchPath("Classes/public"),
            ],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Security"),
                .linkedFramework("WebKit"),
                .linkedLibrary("c++"),
                .linkedLibrary("z"),
                .linkedLibrary("sqlite3.0"),
            ]
        ),
    ]
)
