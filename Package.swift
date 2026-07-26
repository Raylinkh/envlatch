// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EnvLatch",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "EnvLatchCore", targets: ["EnvLatchCore"]),
        .executable(name: "EnvLatch", targets: ["EnvLatch"]),
    ],
    targets: [
        .target(
            name: "EnvLatchCore",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .executableTarget(
            name: "EnvLatch",
            dependencies: ["EnvLatchCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
            ]
        ),
        .testTarget(
            name: "EnvLatchCoreTests",
            dependencies: ["EnvLatchCore"]
        ),
    ]
)
