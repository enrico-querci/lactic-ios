import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Assignments: which programme each client follows, as a grid of cards that
/// fills an iPad's width. Opening a client or a programme from a card moves
/// to its own tab rather than pushing over this one.
struct StudioAssignmentsTab: View {
    let client: APIClient

    var body: some View {
        NavigationStack {
            StudioAssignmentsView(client: client)
        }
    }
}

/// Which programme each client follows: the web's Assignments page.
struct StudioAssignmentsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var model: AssignmentListModel
    @State private var isCreating = false
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
        _model = State(initialValue: AssignmentListModel(client: client))
    }

    var body: some View {
        Group {
            if !model.hasLoaded, model.isLoading || model.failure == nil {
                LoadingView(String(localized: "Loading assignments"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            } else if !model.hasLoaded, let failure = model.failure {
                StudioInitialFailureView(failure: failure, title: Text("Assignments")) {
                    Task { await model.load() }
                }
            } else {
                content
            }
        }
        .navigationTitle("Assignments")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("New assignment", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            NewAssignmentSheet(client: client, preselectedClientID: nil) { model.didCreate($0) }
        }
        .task { await model.load() }
        .onChange(of: model.statusFilter) {
            Task { await model.load() }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                Picker("Status", selection: $model.statusFilter) {
                    Text("All").tag(AssignmentStatus?.none)
                    ForEach(AssignmentStatus.allCases, id: \.self) { status in
                        Text(verbatim: status.label).tag(AssignmentStatus?.some(status))
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 480)

                if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                }

                if model.orderedAssignments.isEmpty {
                    StudioEmptyCard(
                        title: "No assignments",
                        message: "Assign a programme to a client and it will appear here.",
                        systemImage: "calendar.badge.plus"
                    ) {
                        Button("Assign a programme") { isCreating = true }
                            .lacticButton()
                            .frame(maxWidth: 280)
                    }
                } else {
                    LazyVGrid(
                        columns: dynamicTypeSize.isAccessibilitySize
                            ? [GridItem(.flexible())]
                            : [GridItem(.adaptive(minimum: 380), spacing: LacticSpacing.lg)],
                        spacing: LacticSpacing.lg
                    ) {
                        ForEach(model.orderedAssignments) { assignment in
                            AssignmentCard(assignment: assignment, showsClient: true, model: model)
                        }
                    }
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
        .refreshable { await model.load() }
    }
}

/// One assignment, with its status and the actions that change it. Shared by
/// the Assignments tab and a client's detail, where the client is already
/// known and so not repeated.
struct AssignmentCard: View {
    @Environment(StudioEnvironment.self) private var environment
    @Environment(StudioNavigator.self) private var navigator

    let assignment: ProgramAssignment
    let showsClient: Bool
    let model: AssignmentListModel
    @State private var isConfirmingDeletion = false

    var body: some View {
        HStack(alignment: .top, spacing: LacticSpacing.md) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                HStack(spacing: LacticSpacing.sm) {
                    Text(verbatim: assignment.program.name)
                        .font(.lacticHeadline)
                        .foregroundStyle(LacticColor.textPrimary)
                    StatusBadge(assignment.status.label, tone: assignment.status.tone)
                }
                if showsClient {
                    Button {
                        navigator.openClient(assignment.client.id)
                    } label: {
                        Label {
                            Text(verbatim: assignment.client.name)
                        } icon: {
                            Image(systemName: "person.fill")
                        }
                        .font(.lacticBody)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(LacticColor.accent)
                }
                Text("Starts \(assignment.startDate.formatted(locale: environment.locale))")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
                if let notes = assignment.notes, !notes.isEmpty {
                    Text(verbatim: notes)
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actions
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .studioCard()
        .confirmationDialog(
            "Delete this assignment?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete assignment", role: .destructive) {
                Task { await model.delete(id: assignment.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The sessions \(assignment.client.name) logged against it are deleted too.")
        }
    }

    private var actions: some View {
        Menu {
            Button("Open programme", systemImage: "list.bullet.rectangle") {
                navigator.openProgramme(assignment.program.id)
            }
            Section("Status") {
                ForEach(AssignmentStatus.allCases, id: \.self) { status in
                    Button {
                        Task { await model.setStatus(status, forAssignment: assignment.id) }
                    } label: {
                        Label(status.label, systemImage: status.systemImage)
                    }
                    .disabled(status == assignment.status)
                }
            }
            Button("Delete assignment", systemImage: "trash", role: .destructive) {
                isConfirmingDeletion = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Assignment actions"))
        .disabled(model.isSubmitting)
    }
}

/// The new-assignment form: a programme, a client, a start date, and an
/// optional note the client sees.
struct NewAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var model: NewAssignmentModel
    private let onCreated: (ProgramAssignment) -> Void

    @State private var programID: Int?
    @State private var clientID: Int?
    @State private var startDate = Date.now
    @State private var notes = ""

    init(client: APIClient, preselectedClientID: Int?, onCreated: @escaping (ProgramAssignment) -> Void) {
        _model = State(initialValue: NewAssignmentModel(client: client))
        _clientID = State(initialValue: preselectedClientID)
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                if !model.hasLoaded, let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                        .listRowInsets(EdgeInsets())
                } else if model.hasLoaded, model.programs.isEmpty {
                    Section {
                        Text("Create a programme first — assignments pair a client with one.")
                            .foregroundStyle(LacticColor.textSecondary)
                    }
                } else if model.hasLoaded, model.clients.isEmpty {
                    Section {
                        Text("Invite a client first — assignments pair a programme with one.")
                            .foregroundStyle(LacticColor.textSecondary)
                    }
                } else {
                    fields
                }
            }
            .navigationTitle("New assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Assign", action: submit)
                            .disabled(!canSubmit)
                    }
                }
            }
            .task {
                await model.load()
                if programID == nil, model.programs.count == 1 {
                    programID = model.programs.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        Section {
            Picker("Programme", selection: $programID) {
                Text("Choose a programme").tag(Int?.none)
                ForEach(model.programs) { program in
                    Text(verbatim: program.name).tag(Int?.some(program.id))
                }
            }
            Picker("Client", selection: $clientID) {
                Text("Choose a client").tag(Int?.none)
                ForEach(model.clients) { client in
                    Text(verbatim: client.name).tag(Int?.some(client.id))
                }
            }
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
        }
        Section {
            TextField("Notes for the client (optional)", text: $notes, axis: .vertical)
                .lineLimit(3 ... 6)
        } footer: {
            Text("New assignments start as active and appear in the client's app straight away.")
        }
        if model.hasLoaded, let failure = model.failure {
            Section {
                StudioActionFailureNotice(failure: failure)
            }
            .listRowInsets(EdgeInsets())
        }
    }

    private var canSubmit: Bool {
        programID != nil && clientID != nil && !model.isSubmitting
    }

    private func submit() {
        guard let programID, let clientID else { return }
        Task {
            if let created = await model.create(
                programID: programID, clientID: clientID, startDate: CalendarDate(startDate), notes: notes
            ) {
                onCreated(created)
                dismiss()
            }
        }
    }
}
