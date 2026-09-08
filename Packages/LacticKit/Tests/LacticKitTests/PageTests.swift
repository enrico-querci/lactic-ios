import Foundation
import Testing
@testable import LacticKit

/// Pagination travels in headers; the body is a bare array with no envelope.
@Suite("Header pagination")
struct PageTests {
    /// The exact header names and values a real paginated response carried.
    @Test func readsTheHeadersTheAPIActuallySends() {
        let page = Page(items: [1, 2, 3], headers: [
            "x-total-count": "147", "x-page": "1", "x-per-page": "3", "x-total-pages": "49",
        ])
        #expect(page.totalCount == 147)
        #expect(page.page == 1)
        #expect(page.perPage == 3)
        #expect(page.totalPages == 49)
        #expect(page.hasNextPage)
    }

    /// HTTP header names are case-insensitive and URLSession does not normalise
    /// them, so matching must not assume lowercase.
    @Test func matchesHeaderNamesCaseInsensitively() {
        let page = Page(items: [1], headers: ["X-Total-Count": "10", "X-Total-Pages": "10"])
        #expect(page.totalCount == 10)
        #expect(page.totalPages == 10)
    }

    /// A server that stops sending them should degrade to one full page, not
    /// render nothing.
    @Test func fallsBackWhenHeadersAreMissing() {
        let page = Page(items: [1, 2, 3], headers: [:])
        #expect(page.totalCount == 3)
        #expect(page.page == 1)
        #expect(page.totalPages == 1)
        #expect(!page.hasNextPage)
    }

    @Test func ignoresUnparseableHeaders() {
        let page = Page(items: [1, 2], headers: ["x-total-count": "not a number", "x-page": "0"])
        #expect(page.totalCount == 2)
        #expect(page.page == 1)
    }

    @Test func knowsWhenItIsOnTheLastPage() {
        let page = Page(items: [1], headers: ["x-page": "49", "x-total-pages": "49"])
        #expect(!page.hasNextPage)
    }
}
