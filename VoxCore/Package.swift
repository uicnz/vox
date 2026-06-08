// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoxCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VoxCore", targets: ["VoxCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Clipy/Sauce", branch: "master"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.11.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.9.1"),
    ],
    targets: [
	    .target(
	        name: "VoxCore",
	        dependencies: [
	            "Sauce",
	            .product(name: "Dependencies", package: "swift-dependencies"),
	            .product(name: "DependenciesMacros", package: "swift-dependencies"),
	            .product(name: "Logging", package: "swift-log"),
	        ],
	        path: "Sources/VoxCore",
	        linkerSettings: [
	            .linkedFramework("IOKit")
	        ]
	    ),
        .testTarget(
            name: "VoxCoreTests",
            dependencies: ["VoxCore"],
            path: "Tests/VoxCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
