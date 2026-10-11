import Foundation

/// Input snapshot for task evaluation. Independent of RealityKit and AppModel.
public struct CraftStateSnapshot: Equatable, Sendable, Hashable {
    /// Part definition identifiers currently on the craft (stack and radial).
    public var partIDs: [String]
    /// Human-readable launch blocker titles. Empty means no blockers.
    public var launchBlockers: [String]
    /// Sea-level thrust-to-weight ratio.
    public var thrustToWeightSL: Double

    public init(
        partIDs: [String] = [],
        launchBlockers: [String] = [],
        thrustToWeightSL: Double = 0
    ) {
        self.partIDs = partIDs
        self.launchBlockers = launchBlockers
        self.thrustToWeightSL = thrustToWeightSL
    }

    public var hasLaunchBlockers: Bool { !launchBlockers.isEmpty }

    public func containsPartID(_ id: String) -> Bool {
        partIDs.contains(id)
    }
}

/// Essential BUILD V0 part identifiers recognized by the evaluator.
public enum EssentialPartID: String, Sendable, CaseIterable, Hashable {
    case probeCore = "probe-core"
    case fuelTankS = "fuel-tank-s"
    case engineLiquidSmall = "engine-liquid-small"

    public var displayName: String {
        switch self {
        case .probeCore: return "command core"
        case .fuelTankS: return "fuel tank"
        case .engineLiquidSmall: return "liquid rocket engine"
        }
    }
}

public extension CraftStateSnapshot {
    /// Demo fixtures for the isolated preview and tests only.
    enum DemoFixture: String, CaseIterable, Sendable, Identifiable {
        case empty
        case partial
        case fullyAssembled
        case fullyAssembledBlocked
        case launchReady

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .empty: return "Empty craft"
            case .partial: return "Partially assembled"
            case .fullyAssembled: return "Fully assembled"
            case .fullyAssembledBlocked: return "Assembled but blocked"
            case .launchReady: return "Launch-ready"
            }
        }

        public var snapshot: CraftStateSnapshot {
            switch self {
            case .empty:
                return CraftStateSnapshot(partIDs: [], launchBlockers: ["No command core"], thrustToWeightSL: 0)
            case .partial:
                return CraftStateSnapshot(
                    partIDs: [EssentialPartID.probeCore.rawValue],
                    launchBlockers: ["Missing fuel tank", "Missing engine"],
                    thrustToWeightSL: 0
                )
            case .fullyAssembled:
                return CraftStateSnapshot(
                    partIDs: EssentialPartID.allCases.map(\.rawValue),
                    launchBlockers: [],
                    thrustToWeightSL: 0.8
                )
            case .fullyAssembledBlocked:
                return CraftStateSnapshot(
                    partIDs: EssentialPartID.allCases.map(\.rawValue),
                    launchBlockers: ["Over budget"],
                    thrustToWeightSL: 1.4
                )
            case .launchReady:
                return CraftStateSnapshot(
                    partIDs: EssentialPartID.allCases.map(\.rawValue) + ["nose-cone", "parachute"],
                    launchBlockers: [],
                    thrustToWeightSL: 1.4
                )
            }
        }
    }
}
