import LacticCore
import LacticKit
import LacticUI
import SwiftUI

// Building blocks every Studio destination shares, so the roster, the
// programme builder and the rest read as one product.

/// What a detail column shows before anything is selected in the list beside it.
struct StudioSelectPrompt: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .foregroundStyle(LacticColor.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
    }
}

/// A small header above a list section: the eyebrow type the hero cards use,
/// with room for one trailing control.
struct StudioSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.textSecondary)
                .textCase(.uppercase)
            Spacer()
            trailing()
        }
        .padding(.horizontal, LacticSpacing.sm)
    }
}

extension StudioSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title: title) { EmptyView() }
    }
}

/// A row of a list column: the elevated, bordered card the rest of Studio uses,
/// with the selection drawn as an accent edge. Drawn by hand rather than left
/// to the system highlight, which fills the row with the tint colour — and the
/// tint is lime in dark appearance, where the row's text would not be readable
/// on it.
private struct StudioRowBackground: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
            .fill(isSelected ? LacticColor.accent.opacity(0.14) : LacticColor.surfaceElevated)
            .overlay {
                RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                    .strokeBorder(
                        isSelected ? LacticColor.accent : LacticColor.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .padding(.horizontal, LacticSpacing.lg)
            .padding(.vertical, LacticSpacing.xs)
    }
}

extension View {
    /// A list row as a card. Pass `isSelected` for rows that open something in
    /// the next column.
    func studioListRow(isSelected: Bool = false) -> some View {
        listRowSeparator(.hidden)
            // The card is inset from the cell by `StudioRowBackground`'s padding,
            // so the content's inset is that plus the card's own padding.
            .listRowInsets(EdgeInsets(
                top: LacticSpacing.lg, leading: LacticSpacing.xxl,
                bottom: LacticSpacing.lg, trailing: LacticSpacing.xxl
            ))
            .listRowBackground(StudioRowBackground(isSelected: isSelected))
            .tint(LacticColor.accent)
    }

    /// A list row that is not a card: a notice, an empty state, a header block.
    /// Never selectable, so it cannot be mistaken for something that opens.
    func studioPlainRow() -> some View {
        selectionDisabled()
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: LacticSpacing.xs, leading: LacticSpacing.lg,
                bottom: LacticSpacing.xs, trailing: LacticSpacing.lg
            ))
            .listRowBackground(Color.clear)
            .tint(LacticColor.accent)
    }

    /// The list column treatment: cards on the chalk surface, no system grouping.
    func studioListColumn() -> some View {
        listStyle(.plain)
            // The system outlines a selected row in the tint colour, as a
            // square around the cell that fights the rounded card drawn by
            // `StudioRowBackground`. Matching the tint to the surface here and restoring it on
            // the rows' own content removes the outline and nothing else.
            .tint(LacticColor.surface)
            .scrollContentBackground(.hidden)
            .background(LacticColor.surface)
    }
}

struct StudioActionFailureNotice: View {
    let failure: CoachActionFailure

    var body: some View {
        HStack(alignment: .top, spacing: LacticSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(LacticColor.danger)
                .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(title)
                    .font(.lacticHeadline)
                message
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LacticSpacing.lg)
        .background(
            LacticColor.dangerSurface,
            in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(LacticColor.dangerBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch failure {
        case .offline: "wifi.slash"
        case .planIsFull, .rejected: "exclamationmark.triangle.fill"
        }
    }

    private var title: LocalizedStringKey {
        switch failure {
        case .offline: "You're offline"
        case .planIsFull: "Client limit reached"
        case .rejected: "That action was not completed"
        }
    }

    @ViewBuilder
    private var message: some View {
        switch failure {
        case .offline:
            Text("Check your connection and try again.")
        case .planIsFull:
            Text("No client slots are available. Client limits are managed on Lactic Web.")
        case .rejected(let message):
            // The API's wording is deliberately preserved exactly.
            Text(verbatim: message)
        }
    }
}

struct StudioInitialFailureView: View {
    let failure: CoachActionFailure
    /// A `Text` so it can be a translated key or data, like a client's name.
    let title: Text
    let retry: () -> Void

    var body: some View {
        VStack(spacing: LacticSpacing.lg) {
            StudioActionFailureNotice(failure: failure)
                .frame(maxWidth: 560)
            Button("Try again", action: retry)
                .lacticButton(.secondary)
                .frame(maxWidth: 240)
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
        .navigationTitle(title)
    }
}

struct StudioEmptyCard<Action: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: LacticSpacing.md) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(LacticColor.textMuted)
                .accessibilityHidden(true)
            Text(title)
                .font(.lacticHeadline)
            Text(message)
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textSecondary)
                .multilineTextAlignment(.center)
            action()
                .padding(.top, LacticSpacing.sm)
        }
        .padding(LacticSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            LacticColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }
}

extension View {
    /// The elevated, bordered surface every Studio card sits on.
    func studioCard(radius: CGFloat = LacticRadius.control, padding: CGFloat = LacticSpacing.lg) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LacticColor.surfaceElevated,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LacticColor.border, lineWidth: 1)
            }
    }
}
