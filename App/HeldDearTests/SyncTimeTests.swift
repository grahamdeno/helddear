import XCTest
@testable import HeldDear

final class SyncTimeTests: XCTestCase {
    private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }()
    private let us = Locale(identifier: "en_US")

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testTodayYesterdayAndEarlier() {
        let now = date(2026, 11, 24, 13, 30)
        XCTAssertTrue(SyncTime.line(date(2026, 11, 24, 13, 17), now: now, calendar: cal, locale: us).hasPrefix("today at "))
        XCTAssertTrue(SyncTime.line(date(2026, 11, 23, 21, 5), now: now, calendar: cal, locale: us).hasPrefix("yesterday at "))
        let earlier = SyncTime.line(date(2026, 11, 20, 16, 15), now: now, calendar: cal, locale: us)
        XCTAssertTrue(earlier.hasPrefix("Nov 20 at "), earlier)
        XCTAssertFalse(earlier.contains("2026"), "same year leaves the year off")
        let lastYear = SyncTime.line(date(2025, 12, 31, 9, 0), now: now, calendar: cal, locale: us)
        XCTAssertTrue(lastYear.contains("2025"), lastYear)
    }
}
