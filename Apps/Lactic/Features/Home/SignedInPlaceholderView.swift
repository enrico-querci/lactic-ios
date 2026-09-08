import LacticKit
import SwiftUI

/// Proof that the session works end to end, standing in until the real Home
/// screen lands (order-of-work step 6). It reads only what `/me` returned, so
/// if it renders a name the whole chain worked: sign in, token storage, bearer
/// header, decode.
struct SignedInPlaceholderView: View {
    @Environment(AppEnvironment.self) private var environment
    let user: User

    var body: some View {
        NavigationStack {
            List {
                Section("Signed in") {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Role", value: user.role.rawValue)
                    LabeledContent("User ID", value: String(user.id))
                }

                #if DEBUG
                    Section {
                        NavigationLink("Design system") { DesignSystemGalleryView() }
                    }
                #endif

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await environment.session.signOut() }
                    }
                } footer: {
                    Text("Home, programmes, workout execution and history are next.")
                }
            }
            .navigationTitle("Lactic")
        }
    }
}
