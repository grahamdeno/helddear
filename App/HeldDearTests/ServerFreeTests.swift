import XCTest
@testable import HeldDear

/// 1.0 is server-free (Graham, Nov 24, 2026, plan B): mailed cards and family pages come back in 1.1.
final class ServerFreeTests: XCTestCase {
    func testMailedCardsAndFamilyPagesAreOffIn1_0() {
        XCTAssertFalse(AppFeatures.mailedCards)
        XCTAssertFalse(AppFeatures.familyPages)
        XCTAssertTrue(AppFeatures.serverFree)
    }
}
