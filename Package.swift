// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BasicSocket",
    platforms: [
            .macOS(.v10_15)
        ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BasicSocket",
            targets: ["BasicSocket"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/OpenSSL-Package.git", .upToNextMajor(from: "3.3.3001")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BasicSocket",
            dependencies: [
                .product(name: "OpenSSL", package: "OpenSSL-Package")
            ]),

    ]
)
