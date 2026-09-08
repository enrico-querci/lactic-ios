import SwiftUI

/// A small status pill — an assignment's `active` / `completed` / `paused`, or
/// an invitation's state.
public struct StatusBadge: View {
    public enum Tone: Sendable {
        case neutral, positive, caution, informative

        var foreground: Color {
            switch self {
            case .neutral: LacticColor.textSecondary
            case .positive: LacticColor.success
            case .caution: LacticColor.warning
            case .informative: LacticColor.info
            }
        }

        var background: Color {
            switch self {
            case .neutral: LacticColor.surfacePressed
            case .positive: LacticColor.successSurface
            case .caution: LacticColor.warningSurface
            case .informative: LacticColor.infoSurface
            }
        }
    }

    private let text: String
    private let tone: Tone

    public init(_ text: String, tone: Tone = .neutral) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(.lacticCaption.weight(.medium))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, LacticSpacing.sm)
            .padding(.vertical, LacticSpacing.xs)
            .background(tone.background)
            .clipShape(Capsule())
    }
}

/// One muscle group's configured set count, from a workout's `volume_sets`.
///
/// The label is a localized display name the server produced, not an
/// identifier — it must never be matched on or used as a key.
public struct VolumeChip: View {
    private let muscleGroup: String
    private let sets: Int

    public init(muscleGroup: String, sets: Int) {
        self.muscleGroup = muscleGroup
        self.sets = sets
    }

    public var body: some View {
        HStack(spacing: LacticSpacing.xs) {
            Text(muscleGroup)
                .foregroundStyle(LacticColor.textSecondary)
            Text(sets.formatted())
                .font(.lacticCaption.weight(.semibold).monospacedDigit())
                .foregroundStyle(LacticColor.textPrimary)
        }
        .font(.lacticCaption)
        .padding(.horizontal, LacticSpacing.sm)
        .padding(.vertical, LacticSpacing.xs)
        .background(LacticColor.surfacePressed)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(muscleGroup), \(sets) sets")
    }
}

/// The `A`-`Z` letter identifying an exercise's slot in a workout.
public struct PositionBadge: View {
    private let position: String

    public init(_ position: String) {
        self.position = position
    }

    public var body: some View {
        Text(position)
            .font(.lacticCaption.weight(.bold))
            .foregroundStyle(LacticColor.textPrimary)
            .frame(width: 26, height: 26)
            // Not `accent`: on dark that is near-white, and a row of solid
            // white discs reads as unread badges competing with the exercise
            // name rather than labelling it.
            .background(LacticColor.surfacePressed)
            .clipShape(Circle())
            // An outline, because the fill alone is shared with VolumeChip and
            // a neutral StatusBadge; without it the badges row reads as one
            // undifferentiated family distinguishable only by silhouette.
            .overlay(Circle().strokeBorder(LacticColor.borderStrong, lineWidth: 1))
            .accessibilityLabel("Exercise \(position)")
    }
}

#Preview("Badges") {
    VStack(alignment: .leading, spacing: LacticSpacing.md) {
        HStack {
            StatusBadge("Active", tone: .positive)
            StatusBadge("Paused", tone: .caution)
            StatusBadge("Completed")
            StatusBadge("Custom", tone: .informative)
        }
        HStack {
            VolumeChip(muscleGroup: "Chest", sets: 12)
            VolumeChip(muscleGroup: "Triceps", sets: 9)
        }
        HStack {
            PositionBadge("A")
            PositionBadge("B")
        }
    }
    .padding()
    .background(LacticColor.surface)
}
