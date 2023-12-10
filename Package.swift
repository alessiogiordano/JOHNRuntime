// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
// https://docs.swift.org/package-manager/PackageDescription/index.html

import PackageDescription

let package = Package(
    name: "JOHN Runtime",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "JOHN",
            targets: ["JOHN"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        // .package(url: /* package url */, branch: "main"),
        // .package(path: /* local path string */),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", "1.9.0"..."1.18.0"),
        .package(url: "https://github.com/alessiogiordano/HTMLParser.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "JOHN",
            dependencies: [
            	.product(name: "HTMLParser", package: "HTMLParser"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .testTarget(
            name: "JOHNTests",
            dependencies: ["JOHN"]),
    ]
)
