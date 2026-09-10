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

    /// Set when an invitation link is opened, and routed on ahead of the
    /// session phase.
    ///
    /// An invitation is what decides whether somebody becomes a client at all
    /// (AGENTS.md §2.3), so it outranks whatever the current session is: it
    /// applies signed out, signed in as a different client, and signed in as a
    /// coach.
    var pendingInvitationToken: String?

    // Seeds a pending invitation from the launch arguments.
    //
    // Universal Links need an Apple Team ID, and iOS prompts before handing a
    // custom-scheme URL to the app, so neither can be driven headlessly.
    // `--invite <token>` reaches the same screen through the same code path,
    // alongside the `--*-design-preview` routes.
    #if DEBUG
        func seedInvitationFromLaunchArguments() {
            let arguments = ProcessInfo.processInfo.arguments
            guard let flag = arguments.firstIndex(of: "--invite"),
                  case let next = arguments.index(after: flag), next < arguments.endIndex
            else { return }
            pendingInvitationToken = InvitationLink.token(fromPastedText: arguments[next])
        }
    #endif

    /// Returns whether the URL was an invitation link, so the caller can tell
    /// it apart from a URL nothing in the app owns.
    @discardableResult
    func openInvitation(from url: URL) -> Bool {
        guard let token = InvitationLink.token(from: url) else { return false }
        pendingInvitationToken = token
        return true
    }

    func dismissInvitation() {
        pendingInvitationToken = nil
    }

    private static let localeKey = "app_locale"
    private static let serverKey = "api_server"

    #if DEBUG
        /// Which API a DEBUG build talks to.
        ///
        /// Release builds are always production and have no picker: the choice
        /// exists so a development build can be pointed at the real server to
        /// exercise things a local one cannot, like a Google client id that only
        /// production has configured.
        enum Server: String, CaseIterable, Identifiable {
            case local
            case production

            var id: String {
                rawValue
            }

            var title: String {
                switch self {
                case .local: "Local"
                case .production: "Production"
                }
            }

            var url: URL {
                switch self {
                case .local: URL(string: "http://localhost:3000")!
                case .production: URL(string: "https://lactic-api-production.up.railway.app")!
                }
            }
        }

        private(set) var server: Server
    #endif

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.localeKey)
        let initial = stored.flatMap(AppLocale.init(rawValue:)) ?? .deviceDefault
        locale = initial

        #if DEBUG
            let storedServer = UserDefaults.standard.string(forKey: Self.serverKey)
            let initialServer = storedServer.flatMap(Server.init(rawValue:)) ?? .local
            server = initialServer
            let serverBox = ServerBox(initialServer.url)
        #endif

        // Read through a box rather than capturing `self`, which does not exist
        // yet, and re-read on every request so a language switch takes effect
        // without rebuilding the client.
        let localeBox = LocaleBox(initial)
        #if DEBUG
            let client = APIClient(
                configuration: Self.configuration(localeBox: localeBox, serverBox: serverBox)
            )
            self.serverBox = serverBox
        #else
            let client = APIClient(configuration: Self.configuration(localeBox: localeBox))
        #endif
        self.client = client
        session = SessionStore(client: client)
        outbox = Outbox(client: client)
        self.localeBox = localeBox

        Task { await client.setTokenProvider(session) }
    }

    @ObservationIgnored private let localeBox: LocaleBox
    #if DEBUG
        @ObservationIgnored private let serverBox: ServerBox

        /// Switching servers signs out.
        ///
        /// A refresh token issued by one server is meaningless to the other, so
        /// keeping the session would produce a confusing 401 on the next request
        /// rather than an obvious "you are signed out".
        func applyServer(_ newValue: Server) async {
            guard newValue != server else { return }
            await session.signOut()
            server = newValue
            serverBox.value = newValue.url
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.serverKey)
        }
    #endif

    /// Keeps the value the API client reads in step with the published one.
    func applyLocale(_ newValue: AppLocale) {
        locale = newValue
        localeBox.value = newValue
    }

    #if DEBUG
        private static func configuration(localeBox: LocaleBox, serverBox: ServerBox) -> APIConfiguration {
            APIConfiguration(
                baseURL: serverBox.value,
                resolveBaseURL: { serverBox.value },
                locale: { localeBox.value.headerValue }
            )
        }
    #else
        private static func configuration(localeBox: LocaleBox) -> APIConfiguration {
            APIConfiguration.production(locale: { localeBox.value.headerValue })
        }
    #endif
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

#if DEBUG
    /// Mirrors LocaleBox: something thread-safe for the API client's closure to
    /// read that outlives the initializer.
    final class ServerBox: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: URL

        init(_ value: URL) {
            storage = value
        }

        var value: URL {
            get { lock.withLock { storage } }
            set { lock.withLock { storage = newValue } }
        }
    }
#endif
