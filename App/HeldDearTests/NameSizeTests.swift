import XCTest
@testable import HeldDear

/// Long names step down in size, then wrap (feedback on build 1011).
final class NameSizeTests: XCTestCase {
    func testPage_longNamesGetSmallerButNeverTiny() {
        XCTAssertEqual(NameSize.page("Mom"), 96)
        XCTAssertEqual(NameSize.page("Haiden"), 96)
        XCTAssertEqual(NameSize.page("Susan Holobaugh DeNoyer"), 52)
        XCTAssertGreaterThan(NameSize.page("Christopher"), NameSize.page("Susan Holobaugh DeNoyer"))
    }

    func testSizesNeverGrowWithLength() {
        var last: CGFloat = .infinity
        for n in 1...40 {
            let size = NameSize.page(String(repeating: "a", count: n))
            XCTAssertLessThanOrEqual(size, last)
            last = size
        }
    }

    func testNamesMayWrapToTwoLines() {
        XCTAssertEqual(NameSize.maxLines, 2)
    }
}
