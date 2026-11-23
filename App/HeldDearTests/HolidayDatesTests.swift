import XCTest
@testable import HeldDear

/// A holiday's next date comes from its own rule, never from the day it was added (Graham's report, Nov 22, 2026).
final class HolidayDatesTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

    func testHolidaysUseTheirOwnRule() {
        let now = day(2026, 11, 22)
        // Saved as Nov 20, the day they were added.
        XCTAssertEqual(OccasionRules.nextDate(type: .christmas, month: 11, day: 20, from: now, calendar: cal), day(2026, 12, 25))
        XCTAssertEqual(OccasionRules.nextDate(type: .mothersDay, month: 11, day: 20, from: now, calendar: cal), day(2027, 5, 9))
        XCTAssertEqual(OccasionRules.nextDate(type: .fathersDay, month: 11, day: 20, from: now, calendar: cal), day(2027, 6, 20))
    }

    func testOtherDaysUseTheirSavedDate() {
        let now = day(2026, 11, 22)
        XCTAssertEqual(OccasionRules.nextDate(type: .birthday, month: 12, day: 17, from: now, calendar: cal), day(2026, 12, 17))
        XCTAssertEqual(OccasionRules.nextDate(type: .birthday, month: 1, day: 9, from: now, calendar: cal), day(2027, 1, 9))
        XCTAssertEqual(OccasionRules.nextDate(type: .christmas, month: 1, day: 1, from: day(2026, 12, 25), calendar: cal), day(2026, 12, 25),
                       "today counts")
    }
}
