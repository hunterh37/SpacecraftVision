import Foundation

public struct ComponentValidationResult: Equatable, Sendable {
    public let isSatisfied: Bool
    public let missingParts: [EssentialPartID]

    public var missingDisplayNames: [String] { missingParts.map(\.displayName) }

    public var summary: String {
        if isSatisfied { return "All essential components are present." }
        return "Missing: \(missingDisplayNames.joined(separator: ", "))."
    }
}

public struct DesignValidationResult: Equatable, Sendable {
    public let isSatisfied: Bool
    public let missingParts: [EssentialPartID]
    public let launchBlockers: [String]
    public let thrustToWeightSL: Double
    public let twrMeetsRequirement: Bool

    public var failureReasons: [String] {
        var reasons: [String] = []
        if !missingParts.isEmpty {
            reasons.append("Missing components: \(missingParts.map(\.displayName).joined(separator: ", "))")
        }
        if !launchBlockers.isEmpty {
            reasons.append("Launch blockers: \(launchBlockers.joined(separator: "; "))")
        }
        if !twrMeetsRequirement {
            reasons.append(String(format: "TWR %.2f must be greater than 1.0", thrustToWeightSL))
        }
        return reasons
    }

    public var summary: String {
        if isSatisfied { return "Design checks passed for the current craft and mission." }
        return failureReasons.joined(separator: " ")
    }
}

public enum TaskEvaluator {
    public static let minimumTWR: Double = 1.0

    public static func validateComponents(_ snapshot: CraftStateSnapshot) -> ComponentValidationResult {
        let missing = EssentialPartID.allCases.filter { !snapshot.containsPartID($0.rawValue) }
        return ComponentValidationResult(isSatisfied: missing.isEmpty, missingParts: missing)
    }

    public static func validateDesign(_ snapshot: CraftStateSnapshot) -> DesignValidationResult {
        let components = validateComponents(snapshot)
        let twrOK = snapshot.thrustToWeightSL > minimumTWR
        let satisfied = components.isSatisfied && !snapshot.hasLaunchBlockers && twrOK
        return DesignValidationResult(
            isSatisfied: satisfied,
            missingParts: components.missingParts,
            launchBlockers: snapshot.launchBlockers,
            thrustToWeightSL: snapshot.thrustToWeightSL,
            twrMeetsRequirement: twrOK
        )
    }
}
