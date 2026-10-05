import LacticUI
import SwiftUI

/// Pane widths. The last visible pane takes whatever is left.
private enum StudioPaneWidth {
    static func fixed(level: Int, levels: Int) -> CGFloat {
        switch level {
        case 1: levels == 2 ? 360 : 320
        default: 400
        }
    }

    /// The widths at which a second and a third pane fit beside the others.
    static let twoPanes: CGFloat = 700
    static let threePanes: CGFloat = 1100
}

/// The columns of one tab: a list, what is selected in it, and — for the two
/// tasks that go that deep — what is selected in that.
///
/// Compact width (iPhone, or iPad in a narrow window) is a `NavigationSplitView`,
/// which collapses into pushes. Regular width lays the columns out by hand as
/// panes next to each other, because the sidebar beside them is not a
/// `NavigationSplitView` column — a tab that needs three columns would otherwise
/// be a split view nested in a split view. When the panes do not all fit, the
/// deepest ones win and the first visible pane gets a back button.
struct StudioColumns<Root: View, Second: View, Third: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(StudioNavigator.self) private var navigator

    /// How many columns the tab has: 1 (a page), 2 (list and detail) or 3.
    let levels: Int
    /// How deep the current selection goes, `1 ... levels`.
    let depth: Int
    /// Clears the deepest selection.
    let back: () -> Void
    @ViewBuilder let root: () -> Root
    @ViewBuilder let second: () -> Second
    @ViewBuilder let third: () -> Third

    var body: some View {
        if horizontalSizeClass == .compact {
            compact
        } else {
            GeometryReader { proxy in
                panes(width: proxy.size.width)
            }
        }
    }

    // MARK: - Compact

    @ViewBuilder
    private var compact: some View {
        switch levels {
        case 1:
            NavigationStack { root() }
        case 2:
            NavigationSplitView {
                root()
            } detail: {
                second()
            }
            .navigationSplitViewStyle(.balanced)
        default:
            NavigationSplitView {
                root()
            } content: {
                second()
            } detail: {
                third()
            }
            .navigationSplitViewStyle(.balanced)
        }
    }

    // MARK: - Panes

    private func visibleLevels(width: CGFloat) -> [Int] {
        let fit = width >= StudioPaneWidth.threePanes ? 3 : width >= StudioPaneWidth.twoPanes ? 2 : 1
        let count = min(fit, levels)
        if count >= levels {
            return Array(1 ... levels)
        }
        let last = max(depth, count)
        return Array((last - count + 1) ... last)
    }

    private func panes(width: CGFloat) -> some View {
        let visible = visibleLevels(width: width)
        return HStack(spacing: 0) {
            ForEach(visible, id: \.self) { level in
                let isLast = level == visible.last
                pane(level, isFirst: level == visible.first)
                    .frame(width: isLast ? nil : StudioPaneWidth.fixed(level: level, levels: levels))
                    .frame(maxWidth: isLast ? .infinity : nil)
                if !isLast {
                    Rectangle()
                        .fill(LacticColor.border)
                        .frame(width: 1)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private func pane(_ level: Int, isFirst: Bool) -> some View {
        NavigationStack {
            content(level)
                // Large titles sit flush against the divider, with none of the
                // margin a full-width screen gives them.
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isFirst {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Button {
                                navigator.showsSidebar.toggle()
                            } label: {
                                Label("Sidebar", systemImage: "sidebar.leading")
                            }
                            if level > 1 {
                                Button(action: back) {
                                    Label("Back", systemImage: "chevron.backward")
                                }
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func content(_ level: Int) -> some View {
        switch level {
        case 1: root()
        case 2: second()
        default: third()
        }
    }
}

extension StudioColumns where Second == EmptyView, Third == EmptyView {
    /// A tab that is one page.
    init(@ViewBuilder root: @escaping () -> Root) {
        self.init(levels: 1, depth: 1, back: {}, root: root, second: { EmptyView() }, third: { EmptyView() })
    }
}

extension StudioColumns where Third == EmptyView {
    /// A tab that is a list and its detail.
    init(
        depth: Int, back: @escaping () -> Void,
        @ViewBuilder root: @escaping () -> Root, @ViewBuilder second: @escaping () -> Second
    ) {
        self.init(levels: 2, depth: depth, back: back, root: root, second: second, third: { EmptyView() })
    }
}

extension StudioColumns {
    /// A tab that drills two levels deep.
    init(
        depth: Int, back: @escaping () -> Void,
        @ViewBuilder root: @escaping () -> Root, @ViewBuilder second: @escaping () -> Second,
        @ViewBuilder third: @escaping () -> Third
    ) {
        self.init(levels: 3, depth: depth, back: back, root: root, second: second, third: third)
    }
}

/// The sidebar iPad shows beside the tabs' columns, in place of the tab bar.
struct StudioSidebar: View {
    @Environment(StudioNavigator.self) private var navigator

    let pendingInvitations: Int

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xs) {
            HStack(spacing: LacticSpacing.sm) {
                Image(systemName: "dumbbell.fill")
                    .font(.headline)
                    .foregroundStyle(LacticColor.heroSurface)
                    .frame(width: 36, height: 36)
                    .background(LacticColor.brand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text("Lactic Studio")
                    .font(.lacticHeadline)
            }
            .padding(.horizontal, LacticSpacing.md)
            .padding(.bottom, LacticSpacing.lg)

            row(.clients, "Clients", systemImage: "person.2.fill", count: pendingInvitations)
            row(.programmes, "Programmes", systemImage: "list.bullet.rectangle.fill")
            row(.assignments, "Assignments", systemImage: "calendar.badge.checkmark")
            row(.exercises, "Exercises", systemImage: "dumbbell.fill")

            Spacer(minLength: LacticSpacing.xl)

            row(.account, "Account", systemImage: "person.crop.circle.fill")
        }
        .padding(LacticSpacing.md)
        .padding(.top, LacticSpacing.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LacticColor.surfacePressed.opacity(0.5))
    }

    private func row(
        _ tab: StudioTab, _ title: LocalizedStringKey, systemImage: String, count: Int = 0
    ) -> some View {
        let isSelected = navigator.tab == tab
        return Button {
            navigator.tab = tab
        } label: {
            HStack(spacing: LacticSpacing.md) {
                Label(title, systemImage: systemImage)
                    .font(.lacticBody.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? LacticColor.accent : LacticColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: LacticSpacing.sm)
                if count > 0 {
                    Text(verbatim: count.formatted())
                        .font(.lacticCaption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(LacticColor.textSecondary)
                        .padding(.horizontal, LacticSpacing.sm)
                        .padding(.vertical, LacticSpacing.xs)
                        .background(LacticColor.surfacePressed, in: Capsule())
                }
            }
            .padding(.horizontal, LacticSpacing.md)
            .frame(minHeight: LacticSize.minimumHitTarget)
            .background(
                isSelected ? LacticColor.accent.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
