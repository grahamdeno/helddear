import XCTest
@testable import HeldDear

/// A card for any reason (story 2.8).
final class CardReasonTests: XCTestCase {
    func testEveryReasonHasWordsAndAKey() {
        XCTAssertEqual(CardReason.allCases.count, 6)
        XCTAssertEqual(Set(CardReason.allCases.map(\.serverKey)).count, 6)
        for r in CardReason.allCases {
            XCTAssertFalse(r.label.isEmpty)
            XCTAssertTrue(r.opening.hasSuffix(","), r.rawValue)
            XCTAssertFalse(r.greeting(name: "Sam").contains("\u{2014}"))
        }
        XCTAssertEqual(CardReason.getWell.greeting(name: "Sam"), "Feel better soon, Sam!")
        XCTAssertEqual(CardReason.sympathy.greeting(name: "Sam"), "With love and sympathy, Sam.")
    }

    func testRecordLine() {
        var c = DateComponents(); c.year = 2026; c.month = 11; c.day = 21
        let d = Calendar.current.date(from: c)!
        XCTAssertEqual(CardReason.getWell.recordLine(on: d), "Get-well card, Nov 21")
    }

    func testDayCardsKeepTheirOccasionKey() {
        XCTAssertEqual(MailContext.occasionKey(for: .birthday), "birthday")
        XCTAssertEqual(MailContext.occasionKey(for: .anniversary), "anniversary")
    }
}
