import XCTest
@testable import HeldDear

/// Finds (story 2.9): browse every find, newest first, with filters that stack.
final class FindsBrowseTests: XCTestCase {
    func testEveryFindIsComplete() {
        let ids = Finds.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Ids are unique")
        for f in Finds.catalog {
            XCTAssertFalse(f.name.isEmpty, f.id)
            XCTAssertTrue(f.url.hasPrefix("https://"), f.id)
            XCTAssertFalse(f.kinds.isEmpty, f.id)
            XCTAssertFalse(f.why.contains("\u{2014}"), "No em-dashes: \(f.id)")
            XCTAssertFalse(f.url.contains("utm_") || f.url.contains("fbclid"), "Clean links: \(f.id)")
        }
    }

    func testNewestFirstAndFiltersStack() {
        let all = Finds.browse()
        XCTAssertEqual(all.count, Finds.catalog.count)
        XCTAssertEqual(all.first?.added, "2026-11-21")
        let partnerUnder50 = Finds.browse(fits: [.partner], prices: [.under50])
        XCTAssertFalse(partnerUnder50.isEmpty)
        XCTAssertTrue(partnerUnder50.allSatisfy { $0.fits.contains(.partner) && ($0.fromDollars ?? 999) < 50 })
    }

    func testPriceBands() {
        XCTAssertTrue(FindPrice.under50.contains(49))
        XCTAssertTrue(FindPrice.from50to100.contains(50))
        XCTAssertTrue(FindPrice.from50to100.contains(100))
        XCTAssertTrue(FindPrice.over100.contains(101))
        XCTAssertFalse(FindPrice.under50.contains(nil), "Unknown prices only show without a price filter")
    }

    func testNationalBrandsNeverShowAsFinds() {
        XCTAssertFalse(Finds.browse().contains { $0.dependable }, "Finds is small makers only")
        for kind in [ActKind.cake, .flowers] {
            XCTAssertFalse(Finds.matches(kind: kind, fromKids: false, loves: [], dismissed: [], limit: 20).contains { $0.dependable })
        }
        XCTAssertTrue(Finds.catalog.contains { $0.dependable }, "they stay as quick picks in a plan")
    }

    func testDependablePicksAreForCakeAndFlowers() {
        for f in Finds.catalog where f.dependable {
            XCTAssertTrue(f.kinds.isSubset(of: [.cake, .flowers]), f.id)
        }
    }
}
