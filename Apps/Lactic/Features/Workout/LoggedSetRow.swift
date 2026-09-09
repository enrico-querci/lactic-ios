import LacticKit
import LacticUI
import SwiftUI

/// A performed set. The checkmark means logged, not confirmed by the server;
/// the session's sync indicator reports pending and failed writes separately.
struct LoggedSetRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let set: WorkoutRecorder.Set
    let exerciseID: Int
    let recorder: WorkoutRecorder

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: LacticSpacing.sm))
            : AnyLayout(HStackLayout(spacing: LacticSpacing.sm))

        layout {
            Label("\(set.position)", systemImage: "checkmark.circle.fill")
                .font(.lacticCaption.weight(.semibold).monospacedDigit())
                .foregroundStyle(LacticColor.accent)
                .accessibilityLabel("Set \(set.position), logged")

            NumericField(kind: .weight, value: set.weightKg, onCommit: updateWeight)
                .accessibilityLabel("Weight for set \(set.position)")
            NumericField(kind: .reps, value: Decimal(set.reps), onCommit: updateReps)
                .accessibilityLabel("Reps for set \(set.position)")

            Menu {
                Button("Delete set", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Options for set \(set.position)")
        }
        .padding(LacticSpacing.sm)
        .background(LacticColor.surfacePressed, in: RoundedRectangle(cornerRadius: LacticRadius.control))
        .accessibilityElement(children: .contain)
    }

    private func updateWeight(_ value: Decimal) {
        Task { await recorder.updateSet(set.id, in: exerciseID, weightKg: value, reps: nil) }
    }

    private func updateReps(_ value: Decimal) {
        Task {
            await recorder.updateSet(
                set.id, in: exerciseID, weightKg: nil, reps: Int(truncating: value as NSNumber)
            )
        }
    }

    private func delete() {
        Task { await recorder.deleteSet(set.id, in: exerciseID) }
    }
}
