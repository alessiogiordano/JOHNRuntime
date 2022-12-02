// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
// https://docs.swift.org/package-manager/PackageDescription/index.html

import PackageDescription

let package = Package(
    name: "University Cloud Suite",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "AUXLibrary",
            targets: ["AUXLibrary"]),
        .executable(
            name: "AUXServer",
            targets: ["AUXServer"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/webauthn-swift.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "AUXLibrary",
            dependencies: [
                "AUXClient",
                // 💧 A server-side Swift web framework.
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "WebAuthn", package: "webauthn-swift")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
                // For future versions of the toolchain that might support Swift Regex
                /*
                .unsafeFlags(["-Xfrontend", "-enable-experimental-string-processing"]),
                .unsafeFlags(["-Xfrontend", "-enable-bare-slash-regex"]),
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"])
                 */
            ]),
        .target(
            name: "AUXClient",
            plugins: ["TSCompiler"]),
        .executableTarget(
            name: "AUXServer",
            dependencies: ["AUXLibrary"]),
        .testTarget(
            name: "AUXTests",
            dependencies: ["AUXLibrary", "AUXServer",
            .product(name: "XCTVapor", package: "vapor")]),
        .plugin(
        	name: "TSCompiler",
        	capability: .buildTool(),
            dependencies: []),
    ]
)
