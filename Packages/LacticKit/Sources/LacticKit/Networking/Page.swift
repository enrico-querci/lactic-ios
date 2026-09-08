import Foundation

/// A paginated response.
///
/// The API puts pagination in **headers** and leaves the body a bare JSON
/// array — there is no `{data:, meta:}` envelope anywhere. Only the two
/// `exercises#index` endpoints paginate; every other index returns the whole
/// collection.
public struct Page<Element: Sendable>: Sendable {
    public let items: [Element]
    public let totalCount: Int
    public let page: Int
    public let perPage: Int
    public let totalPages: Int

    public var hasNextPage: Bool {
        page < totalPages
    }

    /// Falls back the way the web client does when a header is missing or
    /// unparseable, so a server that stops sending them degrades to a single
    /// page rather than rendering nothing.
    init(items: [Element], headers: [AnyHashable: Any]) {
        func header(_ name: String) -> Int? {
            guard let raw = headers.first(where: { ($0.key as? String)?.lowercased() == name })?.value,
                  let value = Int(String(describing: raw)), value > 0
            else { return nil }
            return value
        }
        self.items = items
        totalCount = header("x-total-count") ?? items.count
        page = header("x-page") ?? 1
        perPage = header("x-per-page") ?? max(items.count, 1)
        totalPages = header("x-total-pages") ?? 1
    }
}
