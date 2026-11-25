import XCTest
@testable import HeldDear

/// 1.0 (Graham, Nov 24, 2026): mailed cards are back behind Fable's Dec 3 gate; family pages stay off until 1.1.
final class ServerFreeTests: XCTestCase {
    func testMailedCardsOnAndFamilyPagesOffIn1_0() {
        XCTAssertTrue(AppFeatures.mailedCards)
        XCTAssertFalse(AppFeatures.familyPages)
        XCTAssertFalse(AppFeatures.serverFree)
    }

    func testPrivacyLineNamesTheCardException() {
        XCTAssertTrue(AppFeatures.privacyLine.contains("card you choose to mail"))
    }
}
