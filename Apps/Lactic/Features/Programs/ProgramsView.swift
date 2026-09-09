import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct ProgramsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: ProgramsModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadableView(model) { assignments in
                        if assignments.isEmpty {
                            EmptyStateView(
                                title: String(localized: "No programmes yet"),
                                message: String(localized: "Your coach has not assigned one yet."),
                                systemImage: "list.bullet.rectangle"
                            )
                        } else {
                            list(assignments)
                        }
                    }
                }
            }
            .background(LacticColor.surface)
            .navigationTitle(Text("Programmes"))
        }
        .task {
            let model = model ?? ProgramsModel(client: environment.client)
            self.model = model
            await model.load()
        }
    }

    private func list(_ assignments: [ProgramAssignment]) -> some View {
        ScrollView {
            LazyVStack(spacing: LacticSpacing.md) {
                ForEach(assignments) { assignment in
                    NavigationLink {
                        ProgramDetailView(programID: assignment.program.id)
                    } label: {
                        ProgramRow(assignment: assignment, locale: environment.locale)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LacticSpacing.lg)
        }
        .refreshable { await model?.reload() }
    }
}

private struct ProgramRow: View {
    let assignment: ProgramAssignment
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(assignment.program.name)
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                Spacer(minLength: LacticSpacing.sm)
                StatusBadge(
                    ClientFormat.title(for: assignment.status),
                    tone: ClientFormat.tone(for: assignment.status)
                )
            }

            if let description = assignment.program.description, !description.isEmpty {
                Text(description)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }

            Text(subtitle)
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LacticSpacing.lg)
        .background(LacticColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }

    /// Start date, plus the coach's note when there is one — joined the way the
    /// web does it.
    private var subtitle: String {
        var parts = [String(localized: "Starts \(startDate)")]
        if let notes = assignment.notes, !notes.isEmpty {
            parts.append(notes)
        }
        return parts.joined(separator: " · ")
    }

    private var startDate: String {
        guard let date = assignment.startDate.date() else { return assignment.startDate.description }
        return Formatters.date(date, locale: locale)
    }
}
