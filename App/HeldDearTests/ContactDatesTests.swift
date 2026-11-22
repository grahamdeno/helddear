import XCTest
@testable import HeldDear

final class ContactDatesTests: XCTestCase {
    func testOffersOnlyDatesNotAlreadyHere() {
        let dates = [
            ContactDate(label: "anniversary", isAnniversary: true, month: 6, day: 10, year: 2012),
            ContactDate(label: "graduation", isAnniversary: false, month: 5, day: 20, year: nil),
            ContactDate(label: "graduation", isAnniversary: false, month: 5, day: 20, year: nil),
        ]
        XCTAssertEqual(ContactDates.offers(dates, existing: []).count, 2, "the repeated date is offered once")
        let haveAnniversary = ContactDates.offers(dates, existing: [(.anniversary, 6, 10)])
        XCTAssertEqual(haveAnniversary.map(\.label), ["graduation"])
        let birthdaySameDay = ContactDates.offers(dates, existing: [(.birthday, 5, 20)])
        XCTAssertEqual(birthdaySameDay.count, 2, "a birthday on the same day doesn't hide another kind of day")
    }

    func testTitles() {
        XCTAssertEqual(ContactDates.title(ContactDate(label: "anniversary", isAnniversary: true, month: 1, day: 1)), "Anniversary")
        XCTAssertEqual(ContactDates.title(ContactDate(label: "graduation", isAnniversary: false, month: 1, day: 1)), "Graduation")
        XCTAssertEqual(ContactDates.title(ContactDate(label: " ", isAnniversary: false, month: 1, day: 1)), "A day")
    }

    func testBadDatesAreSkipped() {
        let d = ContactDate(label: "x", isAnniversary: false, month: 13, day: 1)
        XCTAssertTrue(ContactDates.offers([d], existing: []).isEmpty)
    }
}
