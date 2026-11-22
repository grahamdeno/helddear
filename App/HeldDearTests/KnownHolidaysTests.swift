import XCTest
@testable import HeldDear

final class KnownHolidaysTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day))! }

    func testFixedAndRuleDates() {
        let nov22 = d(2026, 11, 22)
        XCTAssertEqual(KnownHolidays.named("Kwanzaa")?.nextDate(onOrAfter: nov22, calendar: cal), d(2026, 12, 26))
        XCTAssertEqual(KnownHolidays.named("halloween")?.nextDate(onOrAfter: nov22, calendar: cal), d(2027, 10, 31))
        // Labor Day 2027 is Monday Sep 6, so Grandparents Day is Sunday Sep 12.
        XCTAssertEqual(KnownHolidays.named("Grandparents Day")?.nextDate(onOrAfter: nov22, calendar: cal), d(2027, 9, 12))
        XCTAssertNil(KnownHolidays.named("Diwali")?.nextDate(onOrAfter: nov22, calendar: cal), "the user picks Diwali's day")
    }

    func testOtherCalendarsGiveADateWithinTheYear() {
        let nov22 = d(2026, 11, 22)
        for name in ["Hanukkah", "Rosh Hashanah", "Lunar New Year", "Eid al-Fitr", "Eid al-Adha"] {
            guard let date = KnownHolidays.named(name)?.nextDate(onOrAfter: nov22, calendar: cal) else {
                XCTFail("\(name) has no date"); continue
            }
            XCTAssertGreaterThanOrEqual(date, nov22, name)
            XCTAssertLessThan(date, d(2027, 11, 23), name)
        }
        // Hanukkah 2026 begins at sundown Dec 4; its first full day is Dec 5.
        let hanukkah = KnownHolidays.named("Hanukkah")!.nextDate(onOrAfter: nov22, calendar: cal)!
        XCTAssertEqual(cal.component(.month, from: hanukkah), 12)
    }

    func testMatches() {
        XCTAssertEqual(KnownHolidays.matches("han").map(\.name), ["Hanukkah"])
        XCTAssertEqual(KnownHolidays.matches("eid").count, 2)
        XCTAssertEqual(KnownHolidays.matches("").count, KnownHolidays.all.count)
    }
}
