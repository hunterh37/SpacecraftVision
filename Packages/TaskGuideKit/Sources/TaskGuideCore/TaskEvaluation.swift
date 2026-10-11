import Foundation

/// Result of evaluating essential component presence.
public struct ComponentValidationResult: Equatable, Sendable {
    public let isSatisfied: Bool
    public let missingParts: [EssentialPartID]

    public var missingDisplayNames: [String] {
        missingParts.map(\.displayName)
    }

    public var summary: String {
        if isSatisfied {
            return "All essential components are present."
        }
        let names = missingDisplayNames.joined(separator: ", ")
        return "Missing: \(names)."
    }
}

/// Result of evaluating launch-readiness / preflight constraints.
public struct PreflightValidationResult: Equatable, Sendable {
    public let isSatisfied: Bool
    public let missingParts: [EssentialPartID]
    public let launchBlockers: [String]
    public let thrustToWeightSL: Double
    public let twrMeetsRequirement: Bool

    public var failureReasons: [String] {
        var reasons: [String] = []
        if !missingParts.isEmpty {
            let names = missingParts.map(\.displayName).joined(separator: ", ")
            reasons.append("Missing components: \(names)")
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
        if isSatisfied {
            return "Launch readiness checks passed."
        }
        return failureReasons.joined(separator: " ")
    }
}

/// Pure evaluation helpers. No RealityKit or AppModel dependency.
public enum TaskEvaluator {
    public static let minimumTWR: Double = 1.0

    public static func validateComponents(_ snapshot: CraftStateSnapshot) -> ComponentValidationResult {
        let missing = EssentialPartID.allCases.filter { !snapshot.containsPartID($0.rawValue) }
        return ComponentValidationResult(isSatisfied: missing.isEmpty, missingParts: missing)
    }

    public static func validatePreflight(_ snapshot: CraftStateSnapshot) -> PreflightValidationResult {
        let components = validateComponents(snapshot)
        let twrOK = snapshot.thrustToWeightSL > minimumTWR
        let satisfied = components.isSatisfied && !snapshot.hasLaunchBlockers && twrOK
        return PreflightValidationResult(
            isSatisfied: satisfied,
            missingParts: components.missingParts,
            launchBlockers: snapshot.launchBlockers,
            thrustToWeightSL: snapshot.thrustToWeightSL,
            twrMeetsRequirement: twrOK
        )
    }
}
