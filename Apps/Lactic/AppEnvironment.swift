import Foundation
import LacticCore
import LacticKit
import Observation
import SwiftUI

/// Long-lived objects the app hands down through the environment.
///
/// Constructed once in `LacticApp` and never replaced, so the session survives
/// view identity changes.
@MainActor
@Observable
final class AppEnvironment {
    let client: APIClient
    let session: SessionStore
    /// Owned by the environment rather than a screen: the queue has to outlive
    /// the workout view, so a set logged just before the app is backgrounded
    /// still drains.
    let outbox: Outbox

    /// The app's own locale choice, which drives `Accept-Language` and so
    /// decides which language the API translates exercise content into. Starts
    /// from the device but is deliberately overridable, matching the web's
    /// in-app switcher.
    var locale: AppLocale {
        didSet { UserDefaults.standard.set(locale.rawValue, forKey: Self.localeKey) }
    }

    private static let localeKey = "app_locale"

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.localeKey)
        let initial = stored.flatMap(AppLocale.init(rawValue:)) ?? .deviceDefault
        locale = initial

        // Read through a box rather than capturing `self`, which does not exist
        // yet, and re-read on every request so a language switch takes effect
        // without rebuilding the client.
        let localeBox = LocaleBox(initial)
        let client = APIClient(
            configuration: Self.configuration(localeBox: localeBox)
        )
        self.client = client
        session = SessionStore(client: client)
        outbox = Outbox(client: client)
        self.localeBox = localeBox

        Task { await client.setTokenProvider(session) }
    }

    @ObservationIgnored private let localeBox: LocaleBox

    /// Keeps the value the API client reads in step with the published one.
    func applyLocale(_ newValue: AppLocale) {
        locale = newValue
        localeBox.value = newValue
    }

    private static func configuration(localeBox: LocaleBox) -> APIConfiguration {
        let provider: @Sendable () -> String = { localeBox.value.headerValue }
        #if DEBUG
            // A local server during development. Info.plist's
            // NSAllowsLocalNetworking is what permits plain HTTP to localhost.
            return APIConfiguration.localDevelopment(locale: provider)
        #else
            return APIConfiguration.production(locale: provider)
        #endif
    }
}

/// A tiny thread-safe holder, so the API client's locale closure has something
/// to read that outlives the initializer.
final class LocaleBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: AppLocale

    init(_ value: AppLocale) {
        storage = value
    }

    var value: AppLocale {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}
