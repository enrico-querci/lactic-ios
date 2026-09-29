import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NavigationStack {
            List {
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
            }
            .navigationTitle(Text("Settings"))
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
}
