import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Saved workouts. Made from a workout's menu in the programme builder and
/// added to a week from there; this is where they are reviewed and cleared.
struct StudioTemplatesView: View {
    @Environment(StudioEnvironment.self) private var environment

    @State private var model: TemplateListModel
    @State private var pendingDeletion: WorkoutTemplate?

    init(client: APIClient) {
        _model = State(initialValue: TemplateListModel(client: client))
    }

    var body: some View {
        Group {
            if !model.hasLoaded, let failure = model.failure {
                StudioInitialFailureView(failure: failure, title: Text("Templates")) {
                    Task { await model.load() }
                }
            } else if !model.hasLoaded {
                LoadingView(String(localized: "Loading templates"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            } else {
                content
            }
        }
        .navigationTitle("Templates")
        .confirmationDialog(
            "Delete \(pendingDeletion?.name ?? "")?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: {
                if !$0 {
                    pendingDeletion = nil
                }
            }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { template in
            Button("Delete template", role: .destructive) {
                Task { await model.delete(id: template.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Workouts already made from it are not affected.")
        }
        .task { await model.load() }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                StudioDashboardHeader(
                    eyebrow: "Library",
                    title: "Workout templates",
                    message: "Save workouts as templates and reuse them in any week of any programme."
                )

                if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                }

                if model.templates.isEmpty {
                    StudioEmptyCard(
                        title: "No templates yet",
                        message: "In a programme, open a workout's menu and choose Save as template.",
                        systemImage: "square.on.square"
                    ) {
                        EmptyView()
                    }
                } else {
                    VStack(spacing: LacticSpacing.md) {
                        ForEach(model.templates) { template in
                            HStack(spacing: LacticSpacing.md) {
                                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                                    Text(verbatim: template.name)
                                        .font(.lacticHeadline)
                                    Text("Saved \(Formatters.date(template.createdAt, locale: environment.locale))")
                                        .font(.lacticCaption)
                                        .foregroundStyle(LacticColor.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Button("Delete", role: .destructive) { pendingDeletion = template }
                                    .lacticButton(.danger, size: .small, isEnabled: !model.isSubmitting)
                                    .fixedSize()
                            }
                            .studioCard()
                        }
                    }
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
        .refreshable { await model.load() }
    }
}
