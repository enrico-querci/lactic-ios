import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// The coach's programmes — reusable, and assignable to any number of
/// clients. The web's Programs page.
struct StudioProgramsView: View {
    @Environment(StudioEnvironment.self) private var environment
    @Environment(\.studioNavigate) private var navigate

    @State private var model: ProgramListModel
    @State private var isCreating = false
    @State private var pendingDeletion: Program?

    init(client: APIClient) {
        _model = State(initialValue: ProgramListModel(client: client))
    }

    var body: some View {
        Group {
            if !model.hasLoaded, let failure = model.failure {
                StudioInitialFailureView(failure: failure, title: Text("Programmes")) {
                    Task { await model.load() }
                }
            } else if !model.hasLoaded {
                LoadingView(String(localized: "Loading programmes"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            } else {
                content
            }
        }
        .navigationTitle("Programmes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("New programme", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            ProgramDetailsSheet(
                title: "New programme",
                saveTitle: "Create",
                name: "",
                description: ""
            ) { name, description in
                guard let program = await model.create(name: name, description: description) else {
                    return model.failure
                }
                // An empty programme is only a starting point: open it.
                navigate(.program(id: program.id, name: program.name))
                return nil
            }
        }
        .confirmationDialog(
            "Delete \(pendingDeletion?.name ?? "")?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: {
                if !$0 {
                    pendingDeletion = nil
                }
            }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { program in
            Button("Delete programme", role: .destructive) {
                Task { await model.delete(id: program.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its assignments, and the workouts clients logged against them, are deleted too.")
        }
        // Every time, not once: a rename in the builder should show on return.
        .onAppear { Task { await model.load() } }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                StudioDashboardHeader(
                    eyebrow: "Library",
                    title: "Programmes",
                    message: "Build a programme once, then assign it to as many clients as you like."
                )

                if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                }

                if model.programs.isEmpty {
                    StudioEmptyCard(
                        title: "No programmes yet",
                        message: "Create your first programme, then add weeks and workouts.",
                        systemImage: "list.bullet.rectangle"
                    ) {
                        Button("New programme") { isCreating = true }
                            .lacticButton()
                            .frame(maxWidth: 280)
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 300), spacing: LacticSpacing.lg)],
                        spacing: LacticSpacing.lg
                    ) {
                        ForEach(model.programs) { program in
                            NavigationLink(value: StudioRoute.program(id: program.id, name: program.name)) {
                                ProgramCard(program: program)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete programme", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = program
                                }
                            }
                        }
                    }
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
        .refreshable { await model.load() }
    }
}

private struct ProgramCard: View {
    @Environment(StudioEnvironment.self) private var environment
    let program: Program

    var body: some View {
        HStack(alignment: .top, spacing: LacticSpacing.md) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text(verbatim: program.name)
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                if let description = program.description, !description.isEmpty {
                    Text(verbatim: description)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                        .lineLimit(3)
                }
                Text("Created \(Formatters.date(program.createdAt, locale: environment.locale))")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LacticColor.textMuted)
                .accessibilityHidden(true)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .studioCard()
        .accessibilityElement(children: .combine)
    }
}

/// A programme's name and description — for creating one and for editing it.
///
/// `save` returns the failure to show, or `nil` once it worked.
struct ProgramDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let saveTitle: LocalizedStringKey
    @State var name: String
    @State var description: String
    let save: (String, String) async -> CoachActionFailure?

    @State private var isSaving = false
    @State private var failure: CoachActionFailure?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. Push Pull Legs"))
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2 ... 6)
                }
                if let failure {
                    Section {
                        StudioActionFailureNotice(failure: failure)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(saveTitle) {
                            Task {
                                isSaving = true
                                failure = await save(name.trimmingCharacters(in: .whitespaces), description)
                                isSaving = false
                                if failure == nil {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
