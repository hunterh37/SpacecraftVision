import Foundation

/// Input snapshot for Workshop task evaluation. Independent of RealityKit and AppModel.
public struct CraftStateSnapshot: Equatable, Sendable, Hashable {
    public var missionID: String
    public var partIDs: [String]
    public var launchBlockers: [String]
    public var thrustToWeightSL: Double
    public var wetMass: Double
    public var massCap: Double
    public var cost: Int
    public var budget: Int
    public var partCount: Int
    public var partCap: Int
    public var workshopTabletop: Bool

    public init(
        missionID: String = "",
        partIDs: [String] = [],
        launchBlockers: [String] = [],
        thrustToWeightSL: Double = 0,
        wetMass: Double = 0,
        massCap: Double = 0,
        cost: Int = 0,
        budget: Int = 0,
        partCount: Int = 0,
        partCap: Int = 0,
        workshopTabletop: Bool = false
    ) {
        self.missionID = missionID
        self.partIDs = partIDs
        self.launchBlockers = launchBlockers
        self.thrustToWeightSL = thrustToWeightSL
        self.wetMass = wetMass
        self.massCap = massCap
        self.cost = cost
        self.budget = budget
        self.partCount = partCount
        self.partCap = partCap
        self.workshopTabletop = workshopTabletop
    }

    public var hasLaunchBlockers: Bool { !launchBlockers.isEmpty }

    public func containsPartID(_ id: String) -> Bool {
        partIDs.contains(id)
    }
}

public enum EssentialPartID: String, Sendable, CaseIterable, Hashable {
    case probeCore = "probe-core"
    case fuelTankS = "fuel-tank-s"
    case engineLiquidSmall = "engine-liquid-small"

    public var displayName: String {
        switch self {
        case .probeCore: return "Probe Core"
        case .fuelTankS: return "Fuel Tank S"
        case .engineLiquidSmall: return "Liquid Engine S"
        }
    }

    public var roleExplanation: String {
        switch self {
        case .probeCore: return "The probe core is the command brain of the rocket. It holds control and mission systems."
        case .fuelTankS: return "The fuel tank stores propellant the engine burns during flight."
        case .engineLiquidSmall: return "The liquid engine generates thrust to lift the rocket."
        }
    }
}
