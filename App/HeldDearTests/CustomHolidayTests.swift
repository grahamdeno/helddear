import XCTest
@testable import HeldDear

final class CustomHolidayTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "custom-holiday-tests-\(UUID().uuidString)")!
        return d
    }

    func testAddRenameRemove() {
        let d = defaults()
        CustomHolidays.upsert(CustomHoliday(name: "Hanukkah", month: 12, day: 14), d)
        XCTAssertEqual(CustomHolidays.all(d).map(\.name), ["Hanukkah"])
        CustomHolidays.upsert(CustomHoliday(name: "Chanukah", month: 12, day: 4), replacing: "Hanukkah", d)
        XCTAssertEqual(CustomHolidays.all(d).map(\.name), ["Chanukah"])
        XCTAssertEqual(CustomHolidays.find("chanukah", d)?.day, 4)
        CustomHolidays.remove("Chanukah", d)
        XCTAssertTrue(CustomHolidays.all(d).isEmpty)
    }

    func testProblems() {
        let existing = [CustomHoliday(name: "Diwali", month: 11, day: 8)]
        XCTAssertEqual(CustomHolidays.problem(name: "  ", month: 1, day: 1, existing: existing), .empty)
        XCTAssertEqual(CustomHolidays.problem(name: "christmas", month: 1, day: 1, existing: existing), .taken)
        XCTAssertEqual(CustomHolidays.problem(name: "DIWALI", month: 1, day: 1, existing: existing), .taken)
        XCTAssertNil(CustomHolidays.problem(name: "Diwali", month: 11, day: 1, existing: existing, except: "Diwali"))
        XCTAssertEqual(CustomHolidays.problem(name: "Odd", month: 2, day: 30, existing: existing), .badDate)
        XCTAssertNil(CustomHolidays.problem(name: "Leap", month: 2, day: 29, existing: existing))
    }

    func testRefsKeepAddedHolidaysApart() {
        let a = HolidayRef(type: .custom, name: "Hanukkah")
        XCTAssertEqual(a.raw, "custom:Hanukkah")
        XCTAssertEqual(HolidayRef(raw: "custom:Hanukkah"), a)
        XCTAssertEqual(HolidayRef(raw: "christmas"), HolidayRef(type: .christmas))
        XCTAssertNil(HolidayRef(raw: "birthday"))
        XCTAssertNil(HolidayRef(raw: "custom:"))
        XCTAssertTrue(a.matches(type: .custom, partner: "hanukkah"))
        XCTAssertFalse(a.matches(type: .custom, partner: "Diwali"))
        XCTAssertEqual(a.label, "Hanukkah")
        XCTAssertNotEqual(Holidays.groupKey(type: .custom, year: 2026, partner: "Hanukkah"),
                          Holidays.groupKey(type: .custom, year: 2026, partner: "Diwali"))
        XCTAssertEqual(Holidays.groupKey(type: .christmas, year: 2026), "christmas-2026")
    }

    func testAlertWords() {
        XCTAssertEqual(Holidays.headsUpText(type: .custom, people: 3, partner: "Hanukkah"),
                       "Hanukkah is in 6 weeks. 3 people to plan for. If the date moves this year, change it in You.")
        XCTAssertEqual(Holidays.dayOfText(type: .custom, people: 1, partner: "Hanukkah"),
                       "Today is Hanukkah. Held Dear has your messages ready for 1 person.")
        XCTAssertEqual(Holidays.headsUpText(type: .christmas, people: 2), "Christmas is in 6 weeks. 2 people to plan for.")
        XCTAssertEqual(OccasionType.custom.subject(name: "Mom", partner: "Hanukkah"), "Hanukkah for Mom")
    }
}
