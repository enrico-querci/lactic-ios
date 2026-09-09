import LacticUI
import SwiftUI

struct WorkoutOverviewHeader: View {
    let name: String
    let exerciseCount: Int
    let targetSets: Int
    let loggedSets: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.lg) {
            Label {
                if loggedSets != nil {
                    Text("Workout in progress")
                } else {
                    Text("Your workout")
                }
            } icon: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
            .font(.lacticEyebrow)
            .foregroundStyle(LacticColor.brand)

            Text(name)
                .font(.lacticTitle)
                .foregroundStyle(LacticColor.textOnHero)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: LacticSpacing.lg) {
                Text("\(exerciseCount) exercises")
                if let loggedSets {
                    Text("\(loggedSets) sets logged")
                } else {
                    Text("\(targetSets) target sets")
                }
            }
            .font(.subheadline.weight(.medium).monospacedDigit())
            .foregroundStyle(LacticColor.textOnHero)
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card))
    }
}
