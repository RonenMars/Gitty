// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Gitty",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "Gitty", targets: ["Gitty"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ibrahimcetin/libgit2", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: "Gitty",
            dependencies: [
                .product(name: "libgit2", package: "libgit2"),
            ]
        ),
        .testTarget(
            name: "GittyTests",
            dependencies: ["Gitty"]
        ),
    ]
)
