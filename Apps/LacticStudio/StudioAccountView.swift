import LacticKit
import LacticUI
import SwiftUI

/// Account: the plan and the coach's own profile on one page. Side by side
/// where there is room, stacked on iPhone.
struct StudioAccountView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let roster: ClientListModel
    let name: String
    let email: String
    let signOut: () -> Void
    let deleteAccount: () async throws -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                let layout = horizontalSizeClass == .compact
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: LacticSpacing.xl))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: LacticSpacing.xl))

                layout {
                    section("Plan") {
                        StudioPlanSection(roster: roster)
                    }
                    section("Profile") {
                        StudioProfileSection(
                            name: name, email: email, signOut: signOut, deleteAccount: deleteAccount
                        )
                    }
                }
                .padding(LacticSpacing.xl)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .background(LacticColor.surface)
            .navigationTitle("Account")
            .refreshable { await roster.load() }
        }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            Text(title)
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.textSecondary)
                .textCase(.uppercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
