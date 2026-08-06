// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FinanceApp",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "FinanceAppDependencies",
            targets: ["FinanceAppDependencies"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/airbnb/lottie-ios.git",
            from: "4.6.0"
        )
    ],
    targets: [
        .target(
            name: "FinanceAppDependencies",
            dependencies: [
                .product(name: "Lottie", package: "lottie-ios")
            ],
            path: "PackageSupport"
        )
    ]
)
