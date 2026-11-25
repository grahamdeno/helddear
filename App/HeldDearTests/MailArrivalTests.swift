import XCTest
@testable import HeldDear

final class MailArrivalTests: XCTestCase {
    private var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }()
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day))! }

    func testEstimateSkipsWeekends() {
        // Friday Dec 4, 2026: mailed Mon Dec 7 to Wed Dec 9; arrives Dec 9 to Dec 16.
        let e = MailArrival.estimate(orderedOn: d(2026, 12, 4), calendar: cal)
        XCTAssertEqual(e.earliest, d(2026, 12, 9))
        XCTAssertEqual(e.latest, d(2026, 12, 16))
    }

    func testChristmasLineBeforeAndAfterTheCutoff() {
        let by = d(2026, 12, 13)
        XCTAssertEqual(MailArrival.christmasLine(today: d(2026, 12, 13), orderBy: by, calendar: cal), "Order by Dec 13 for Christmas.")
        XCTAssertEqual(MailArrival.christmasLine(today: d(2026, 12, 14), orderBy: by, calendar: cal), "Cards ordered now arrive after Christmas.")
        XCTAssertNil(MailArrival.christmasLine(today: d(2026, 10, 1), orderBy: by, calendar: cal))
        XCTAssertNil(MailArrival.christmasLine(today: d(2026, 12, 1), orderBy: nil, calendar: cal))
    }

    func testReadsTheServersDate() {
        XCTAssertEqual(MailArrival.day(fromISO: "2026-12-13", calendar: cal), d(2026, 12, 13))
        XCTAssertNil(MailArrival.day(fromISO: "soon", calendar: cal))
    }
}
