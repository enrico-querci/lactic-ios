import Foundation
import LacticCore
import LacticKit
import Observation
import SwiftUI

/// Long-lived objects Studio hands down through the environment.
///
/// Deliberately smaller than the client's `AppEnvironment`: there is no outbox
/// here. A coach edits programmes at a desk, while a client logs sets mid-set
/// in a basement — the durable queue exists for the second case, and adding it
/// speculatively would mean maintaining a write path nothing exercises.
@MainActor
@Observable
final class StudioEnvironment {
    let client: APIClient
    let session: SessionStore

    /// Drives `Accept-Language`, and so which language the API translates
    /// exercise content into.
    var locale: AppLocale {
        didSet { UserDefaults.standard.set(locale.rawValue, forKey: Self.localeKey) }
    }

    private static let localeKey = "app_locale"
    private static let serverKey = "api_server"

    #if DEBUG
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

    @ObservationIgnored private let localeBox: LocaleBox
    #if DEBUG
        @ObservationIgnored private let serverBox: ServerBox
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

        let localeBox = LocaleBox(initial)
        #if DEBUG
            let client = APIClient(configuration: APIConfiguration(
                baseURL: serverBox.value,
                resolveBaseURL: { serverBox.value },
                locale: { localeBox.value.headerValue }
            ))
            self.serverBox = serverBox
        #else
            let client = APIClient(
                configuration: APIConfiguration.production(locale: { localeBox.value.headerValue })
            )
        #endif
        self.client = client
        self.localeBox = localeBox
        // The keychain service derives from the bundle id, so Studio's session
        // is its own — signing out of one app leaves the other alone.
        session = SessionStore(client: client)
        Task { await client.setTokenProvider(session) }
    }

    func applyLocale(_ newValue: AppLocale) {
        locale = newValue
        localeBox.value = newValue
    }

    #if DEBUG
        /// Switching servers signs out: the tokens are issued per environment,
        /// so carrying them across would fail on the first authenticated call.
        func applyServer(_ newValue: Server) async {
            guard newValue != server else { return }
            server = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.serverKey)
            serverBox.value = newValue.url
            await session.signOut()
        }
    #endif
}

/// A tiny thread-safe holder, so the API client's closures have something to
/// read that outlives a value type.
private final class LocaleBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AppLocale
    init(_ value: AppLocale) {
        stored = value
    }

    var value: AppLocale {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

#if DEBUG
    private final class ServerBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: URL
        init(_ value: URL) {
            stored = value
        }

        var value: URL {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }
#endif
