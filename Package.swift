// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "OneDrive",
    products: [
        .library(
            name: "OneDrive",
            targets: ["OneDrive"])
    ],
    dependencies: [
        
    ],
    targets: [
        .target(
            name: "OneDrive",
            dependencies: []),
        .testTarget(
            name: "OneDriveTests",
            dependencies: ["OneDrive"])
    ]
)
