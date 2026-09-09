import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct ProgramsDashboard: View {
    let assignments: [ProgramAssignment]
    let locale: AppLocale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                ProgramsOverview(programmeCount: assignments.count)

                ForEach(assignments) { assignment in
                    NavigationLink {
                        ProgramDetailView(programID: assignment.program.id)
                    } label: {
                        ProgrammeCard(assignment: assignment, locale: locale)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LacticSpacing.lg)
        }
    }
}

private struct ProgramsOverview: View {
    let programmeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Label("Your training", systemImage: "figure.strengthtraining.traditional")
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.brand)

            Text("Built by your coach. Ready when you are.")
                .font(.lacticTitle)
                .foregroundStyle(LacticColor.textOnHero)
                .fixedSize(horizontal: false, vertical: true)

            if programmeCount == 1 {
                Text("1 active programme")
                    .font(.lacticCaption.monospacedDigit())
                    .foregroundStyle(LacticColor.textOnHero)
            } else {
                Text("\(programmeCount) active programmes")
                    .font(.lacticCaption.monospacedDigit())
                    .foregroundStyle(LacticColor.textOnHero)
            }
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card))
    }
}

private struct ProgrammeCard: View {
    let assignment: ProgramAssignment
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                StatusBadge(
                    ClientFormat.title(for: assignment.status),
                    tone: ClientFormat.tone(for: assignment.status)
                )
                Spacer(minLength: LacticSpacing.sm)
                Image(systemName: "arrow.up.right")
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.accent)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text(assignment.program.name)
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = assignment.program.description, !description.isEmpty {
                    Text(description)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Label(startDate, systemImage: "calendar")
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textSecondary)

            if let notes = assignment.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: LacticSpacing.sm) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(LacticColor.accent)
                        .accessibilityHidden(true)
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(LacticColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(LacticSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LacticColor.surfacePressed, in: RoundedRectangle(cornerRadius: LacticRadius.control))
            }

            HStack {
                Text("View programme")
                    .font(.lacticHeadline)
                Spacer(minLength: LacticSpacing.sm)
                Image(systemName: "arrow.right")
                    .font(.lacticHeadline)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(LacticColor.accent)
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.surfaceElevated, in: RoundedRectangle(cornerRadius: LacticRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
        .accessibilityHint("Opens this programme")
    }

    private var startDate: String {
        let date = assignment.startDate.date()
            .map { Formatters.date($0, locale: locale) }
            ?? assignment.startDate.description
        return String(localized: "Starts \(date)")
    }
}
