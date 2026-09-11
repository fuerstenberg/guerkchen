// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GuerkchenCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GuerkchenCore", targets: ["GuerkchenCore"])
    ],
    targets: [
        .target(
            name: "GuerkchenCore",
            resources: [.copy("Resources/gherkin-languages.json")]
        ),
        .testTarget(
            name: "GuerkchenCoreTests",
            dependencies: ["GuerkchenCore"]
        )
    ]
)
