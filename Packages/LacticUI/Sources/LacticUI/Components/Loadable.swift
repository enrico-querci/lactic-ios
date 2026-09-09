import SwiftUI

/// The state of something fetched from the API.
///
/// `idle` is distinct from `loading` so a screen can tell "not asked yet" from
/// "asked, waiting" — the difference between showing nothing and showing a
/// spinner on first appearance.
public enum Loadable<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    public var value: Value? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }

    /// True while a *first* load is in flight. A refresh over existing content
    /// keeps the content on screen instead of replacing it with a spinner.
    public var isLoadingFirstTime: Bool {
        switch self {
        case .idle, .loading: true
        case .loaded, .failed: false
        }
    }
}

extension Loadable: Equatable where Value: Equatable {}

/// Something a screen loads and can retry.
///
/// Every client screen has the same shape — hold a `Loadable`, reload on
/// failure — so `LoadableView` takes the source itself rather than a state and
/// a separate retry closure. That leaves one trailing closure at the call site
/// instead of two, and removes the retry wiring each screen would otherwise
/// repeat.
@MainActor
public protocol LoadableSource: AnyObject {
    associatedtype Value: Sendable
    var state: Loadable<Value> { get }
    func reload() async
}

/// Renders a `LoadableSource` as loading, error-with-retry, or content.
///
/// Exists so every screen handles the three states the same way. The web's own
/// note on why the error case matters is worth keeping in mind: gym wifi fails
/// routinely, and a blank screen is indistinguishable from "you have no
/// programmes" — a much more alarming thing for a client to conclude.
public struct LoadableView<Source: LoadableSource, Content: View>: View {
    private let source: Source?
    private let content: (Source.Value) -> Content

    /// Accepts an **optional** source deliberately.
    ///
    /// These screens create their model inside `.task`, so it is nil on the
    /// first render. Writing `Group { if let model { LoadableView(model) } }`
    /// and hanging `.task` off the Group looks equivalent and is not: with no
    /// else branch the Group resolves to nothing, SwiftUI never materialises
    /// it, and the `.task` that would have created the model never runs. The
    /// screen stays blank forever — a deadlock, not a race, so it never
    /// resolves on its own.
    ///
    /// That shipped once, in the workout execution screen. Handling nil here
    /// means no screen needs the conditional wrapper, so the shape cannot recur.
    public init(_ source: Source?, @ViewBuilder content: @escaping (Source.Value) -> Content) {
        self.source = source
        self.content = content
    }

    public var body: some View {
        switch source?.state {
        case .none, .idle, .loading:
            LoadingView()
        case .loaded(let value):
            content(value)
        case .failed(let message):
            ErrorStateView(message: message) {
                if let source {
                    Task { await source.reload() }
                }
            }
            .padding(LacticSpacing.lg)
        }
    }
}
