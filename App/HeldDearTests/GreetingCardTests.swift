import XCTest
@testable import HeldDear

final class GreetingCardTests: XCTestCase {
    func testChoicesAreHolidaysThenReasonsThenOwnWords() {
        let c = GreetingCard.choices(holidays: [.christmas])
        XCTAssertEqual(c.first, .holiday(.christmas))
        XCTAssertEqual(c.last, .ownWords)
        XCTAssertEqual(c.count, 1 + CardReason.allCases.count + 1)
    }

    func testHeadings() {
        XCTAssertEqual(GreetingCard.Occasion.holiday(.christmas).heading, "Merry Christmas")
        XCTAssertEqual(GreetingCard.Occasion.reason(.thankYou).heading, "Thank you")
        XCTAssertEqual(GreetingCard.Occasion.ownWords.heading, "")
        XCTAssertEqual(GreetingCard.Occasion.holiday(.christmas).holidayType, .christmas)
        XCTAssertNil(GreetingCard.Occasion.reason(.thankYou).holidayType)
    }

    func testSignature() {
        XCTAssertEqual(GreetingCard.signature(" The DeNoyers "), "from The DeNoyers")
        XCTAssertEqual(GreetingCard.signature("  "), "")
    }

    func testTiming() {
        XCTAssertEqual(GreetingCard.duration(photos: 1), 4.0, accuracy: 0.001)
        XCTAssertGreaterThan(GreetingCard.duration(photos: 5), GreetingCard.duration(photos: 1))
        XCTAssertEqual(GreetingCard.slide(at: 0, photos: 3).index, 0)
        XCTAssertEqual(GreetingCard.slide(at: 1.7, photos: 3).index, 1)
        XCTAssertEqual(GreetingCard.slide(at: 99, photos: 3).index, 2)
        XCTAssertEqual(GreetingCard.slide(at: 1.6, photos: 3).fade, 0, accuracy: 0.001)
    }
}
