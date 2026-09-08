import Foundation

/// Caches exercise animation bytes.
///
/// This exists because of a specific server-side decision: the animation
/// endpoint sends `Cache-Control: private, no-store`, deliberately, on
/// licensing grounds — so `URLCache` will not retain anything and every scroll
/// past an exercise would otherwise re-fetch. Each fetch also costs one request
/// from a metered monthly provider quota, so re-fetching is not merely slow, it
/// is billable.
///
/// Memory first for the current screen, disk so it survives a relaunch.
public actor AnimationCache {
    public static let shared = AnimationCache()

    private let memory = NSCache<NSString, NSData>()
    private let directory: URL?
    private let fileManager = FileManager.default

    public init(directoryName: String = "ExerciseAnimations", byteLimit: Int = 32 * 1024 * 1024) {
        memory.totalCostLimit = byteLimit

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        directory = caches?.appendingPathComponent(directoryName, isDirectory: true)
        if let directory {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    public func data(for key: String) -> Data? {
        if let cached = memory.object(forKey: key as NSString) {
            return cached as Data
        }
        guard let url = fileURL(for: key), let data = try? Data(contentsOf: url) else { return nil }
        memory.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        return data
    }

    public func store(_ data: Data, for key: String) {
        memory.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        guard let url = fileURL(for: key) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public func removeAll() {
        memory.removeAllObjects()
        guard let directory else { return }
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Keys come from API paths, which contain slashes. Hash rather than escape,
    /// so a key can never climb out of the cache directory.
    private func fileURL(for key: String) -> URL? {
        directory?.appendingPathComponent(String(format: "%02x", abs(key.hashValue)) + "-" + String(key.count))
    }
}
