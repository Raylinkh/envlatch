// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentKeyring",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AgentKeyringCore", targets: ["AgentKeyringCore"]),
        .executable(name: "AgentKeyring", targets: ["AgentKeyring"]),
    ],
    targets: [
        .target(
            name: "AgentKeyringCore",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .executableTarget(
            name: "AgentKeyring",
            dependencies: ["AgentKeyringCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
            ]
        ),
        .testTarget(
            name: "AgentKeyringCoreTests",
            dependencies: ["AgentKeyringCore"]
        ),
    ]
)
