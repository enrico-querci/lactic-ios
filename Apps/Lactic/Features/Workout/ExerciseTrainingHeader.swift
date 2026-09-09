import LacticUI
import SwiftUI

struct ExerciseTrainingHeader: View {
    let position: String
    let name: String
    let loggedCount: Int
    let targetCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            HStack(alignment: .top, spacing: LacticSpacing.md) {
                Text(position)
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.heroSurface)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(LacticColor.brand, in: RoundedRectangle(cornerRadius: LacticRadius.control))
                    .accessibilityLabel("Exercise \(position)")
                Text(name)
                    .font(.title2.bold())
                    .foregroundStyle(LacticColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("\(loggedCount) of \(targetCount) sets logged")
                    Spacer(minLength: LacticSpacing.sm)
                    if targetCount > 0, loggedCount >= targetCount {
                        Label("Target reached", systemImage: "checkmark.circle.fill")
                    }
                }
                Text("\(loggedCount) of \(targetCount) sets logged")
            }
            .font(.lacticCaption)
            .foregroundStyle(LacticColor.accent)
            ProgressView(value: Double(min(loggedCount, targetCount)), total: Double(max(targetCount, 1)))
                .tint(LacticColor.accent)
                .accessibilityHidden(true)
        }
    }
}
