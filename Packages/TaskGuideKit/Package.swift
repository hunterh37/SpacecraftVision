// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TaskGuideKit",
    platforms: [.macOS(.v15), .visionOS(.v2)],
    products: [
        .library(name: "TaskGuideCore", targets: ["TaskGuideCore"]),
        .library(name: "TaskGuideUI", targets: ["TaskGuideUI"]),
    ],
    targets: [
        .target(name: "TaskGuideCore"),
        .target(name: "TaskGuideUI", dependencies: ["TaskGuideCore"]),
        .testTarget(name: "TaskGuideCoreTests", dependencies: ["TaskGuideCore"]),
        .testTarget(name: "TaskGuideUITests", dependencies: ["TaskGuideUI", "TaskGuideCore"]),
    ]
)
