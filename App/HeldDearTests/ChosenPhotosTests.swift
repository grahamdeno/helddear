import XCTest
@testable import HeldDear

final class ChosenPhotosKeepTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day))! }

    func testPhotosNearTheirDaysAreAlwaysKept() {
        XCTAssertTrue(ChosenPhotos.nearDay(d(2019, 12, 15), days: [(12, 17)], within: 3, calendar: cal))
        XCTAssertFalse(ChosenPhotos.nearDay(d(2019, 12, 10), days: [(12, 17)], within: 3, calendar: cal))
        XCTAssertTrue(ChosenPhotos.nearDay(d(2020, 1, 1), days: [(12, 30)], within: 3, calendar: cal), "across the new year")
    }

    func testOthersAreCappedNearDaysAreNot() {
        let taken: [Date?] = [d(2018, 6, 1), d(2018, 12, 17), nil, d(2019, 12, 18), d(2020, 3, 3)]
        let keep = ChosenPhotos.keep(taken: taken, days: [(12, 17)], within: 3, others: 1, calendar: cal)
        XCTAssertEqual(keep, [true, true, false, true, false])
    }
}
