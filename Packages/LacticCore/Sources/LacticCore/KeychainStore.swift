import Foundation
import Security

/// Somewhere to keep a credential across launches.
///
/// A protocol so tests can substitute memory: the real Keychain in a host test
/// binary is unsigned, and its behaviour there is neither reliable nor worth
/// asserting on.
public protocol SecureStorage: Sendable {
    func string(forKey key: String) throws -> String?
    func set(_ string: String?, forKey key: String) throws
}

/// An in-memory `SecureStorage`, for tests and previews.
public final class InMemoryStorage: SecureStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public func string(forKey key: String) throws -> String? {
        lock.withLock { values[key] }
    }

    public func set(_ string: String?, forKey key: String) throws {
        lock.withLock { values[key] = string }
    }
}

/// Minimal Keychain wrapper for the refresh token.
///
/// The web keeps its refresh token in `localStorage`; the native equivalent is
/// the Keychain, not `UserDefaults`, which is a plist in the app container and
/// readable from a backup.
///
/// `kSecAttrAccessibleAfterFirstUnlock` rather than `WhenUnlocked`: a token
/// refresh can run while the device is locked, and a value that cannot be read
/// then would sign the user out for no reason. It is deliberately not
/// `ThisDeviceOnly` — the intent is that a restored backup keeps you signed in.
public struct KeychainStore: SecureStorage, Sendable {
    public enum Failure: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case dataCorrupted
    }

    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func string(forKey key: String) throws -> String? {
        guard let data = try data(forKey: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else { throw Failure.dataCorrupted }
        return string
    }

    public func set(_ string: String?, forKey key: String) throws {
        guard let string else {
            try removeValue(forKey: key)
            return
        }
        try set(Data(string.utf8), forKey: key)
    }

    public func data(forKey key: String) throws -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw Failure.dataCorrupted }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw Failure.unexpectedStatus(status)
        }
    }

    public func set(_ data: Data, forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw Failure.unexpectedStatus(addStatus) }
        default:
            throw Failure.unexpectedStatus(status)
        }
    }

    public func removeValue(forKey key: String) throws {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.unexpectedStatus(status)
        }
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
