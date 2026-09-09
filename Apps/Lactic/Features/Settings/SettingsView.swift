import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if case .signedIn(let user) = environment.session.phase {
                    Section("Account") {
                        LabeledContent("Name", value: user.name)
                        LabeledContent("Email", value: user.email)
                    }
                }

                Section {
                    Picker("Language", selection: languageBinding) {
                        Text("English").tag(AppLocale.english)
                        Text("Italiano").tag(AppLocale.italian)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Language")
                } footer: {
                    // The API translates exercise names, descriptions,
                    // instructions and the muscle/equipment glossary from this
                    // header, so it is not merely an interface-language switch.
                    Text("Also selects the language your coach's exercise library is shown in.")
                }

                #if DEBUG
                    Section {
                        Picker("Server", selection: serverBinding) {
                            ForEach(AppEnvironment.Server.allCases) { server in
                                Text(server.title).tag(server)
                            }
                        }
                        .pickerStyle(.segmented)

                        NavigationLink("Design system") { DesignSystemGalleryView() }
                    } header: {
                        Text("Developer")
                    } footer: {
                        // A session from one server is meaningless to the
                        // other, so switching signs out rather than leaving a
                        // token that fails confusingly on the next request.
                        Text("Switching servers signs you out. Release builds always use production.")
                    }
                #endif

                Section {
                    Button("Sign out") {
                        Task { await environment.session.signOut() }
                    }
                }

                Section {
                    Button("Delete account", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text(
                        """
                        Permanently removes your account, your programme assignments \
                        and every workout you have logged. This cannot be undone.
                        """
                    )
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.danger)
                    }
                }
            }
            .navigationTitle(Text("Settings"))
            .confirmationDialog(
                "Delete your account?",
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your assignments and logged workouts are deleted too. This cannot be undone.")
            }
        }
    }

    #if DEBUG
        private var serverBinding: Binding<AppEnvironment.Server> {
            Binding(
                get: { environment.server },
                set: { newValue in Task { await environment.applyServer(newValue) } }
            )
        }
    #endif

    private var languageBinding: Binding<AppLocale> {
        Binding(
            get: { environment.locale },
            set: { environment.applyLocale($0) }
        )
    }

    private func deleteAccount() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await environment.client.sendIgnoringResponse(ClientAPI.deleteAccount)
                // The account is gone, so there is no session left to revoke —
                // clear locally rather than calling DELETE /auth.
                await environment.session.clearSession()
            } catch {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
            isDeleting = false
        }
    }
}
