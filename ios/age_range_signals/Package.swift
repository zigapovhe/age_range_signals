// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "age_range_signals",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "age-range-signals", targets: ["age_range_signals"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "age_range_signals",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: ".",
            sources: [
                "Classes",
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
