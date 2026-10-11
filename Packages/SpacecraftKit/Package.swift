// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SpacecraftKit",
    platforms: [.visionOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "SpacecraftCore", targets: ["SpacecraftCore"]),
        .library(name: "FlightSim", targets: ["FlightSim"]),
        .library(name: "FlightCode", targets: ["FlightCode"]),
        .library(name: "FlightRunner", targets: ["FlightRunner"]),
        .library(name: "Curriculum", targets: ["Curriculum"]),
        .library(name: "LabUI", targets: ["LabUI"]),
    ],
    targets: [
        .target(name: "SpacecraftCore"),
        .target(name: "FlightSim", dependencies: ["SpacecraftCore"]),
        .target(name: "FlightCode", dependencies: ["SpacecraftCore"]),
        .target(name: "FlightRunner", dependencies: ["SpacecraftCore", "FlightSim", "FlightCode"]),
        .target(name: "Curriculum", dependencies: ["FlightCode", "SpacecraftCore"]),
        .target(name: "LabUI", dependencies: ["SpacecraftCore", "FlightSim", "FlightCode", "FlightRunner", "Curriculum"]),
        .testTarget(name: "SpacecraftCoreTests", dependencies: ["SpacecraftCore"]),
        .testTarget(name: "FlightSimTests", dependencies: ["FlightSim"]),
        .testTarget(name: "FlightCodeTests", dependencies: ["FlightCode"]),
        .testTarget(name: "FlightRunnerTests", dependencies: ["FlightRunner", "Curriculum"]),
        .testTarget(name: "LabUITests", dependencies: ["LabUI", "FlightRunner", "Curriculum"]),
    ]
)
