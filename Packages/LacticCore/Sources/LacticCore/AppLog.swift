import Foundation
import OSLog

/// Shared `Logger` categories.
///
/// `AGENTS.md` 2.4 is explicit that client records hold real gym members'
/// personal data and that no report may leak it, even indirectly — the API's
/// Sentry integration carries only `{ id, role }`. The same rule applies to
/// device logs, which end up in sysdiagnoses and bug reports, so `redacting`
/// exists to make the safe thing the easy thing at call sites.
public enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.enricoquerci.lactic"

    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let outbox = Logger(subsystem: subsystem, category: "outbox")
    public static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Reduces an identifying string to something safe to log: an email keeps
    /// its domain, a token keeps nothing but its length.
    public static func redacting(email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return "<redacted>" }
        return "***\(email[at...])"
    }

    public static func redacting(token: String) -> String {
        "<token \(token.count) chars>"
    }
}
