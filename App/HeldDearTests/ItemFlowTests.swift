import XCTest
@testable import HeldDear

final class ItemFlowTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day))! }

    func testCakeQuestionsAndDates() {
        XCTAssertEqual(ItemFlow.question(kind: .cake, path: [], name: "Ada", canShipToThem: false)?.options.map(\.path), [.make, .buy])
        XCTAssertEqual(ItemFlow.question(kind: .cake, path: [.buy], name: "Ada", canShipToThem: false)?.options.map(\.path), [.local, .online])
        XCTAssertNil(ItemFlow.question(kind: .cake, path: [.buy, .local], name: "Ada", canShipToThem: false))
        let f = ItemFlow.finish(kind: .cake, path: [.buy, .local])
        XCTAssertEqual(f.ask, .place)
        let dates = ItemFlow.dates(f, due: d(2026, 12, 17), now: d(2026, 11, 22), calendar: cal)
        XCTAssertEqual(dates.map(\.date), [d(2026, 12, 13), d(2026, 12, 16)])
    }

    func testGiftAsksWhereToShipOnlyWhenItCan() {
        XCTAssertNil(ItemFlow.question(kind: .gift, path: [.online], name: "Ada", canShipToThem: false))
        XCTAssertEqual(ItemFlow.question(kind: .gift, path: [.online], name: "Ada", canShipToThem: true)?.options.map(\.path), [.toYou, .toThem])
        XCTAssertEqual(ItemFlow.finish(kind: .gift, path: [.online, .toThem]).deadlines.first?.daysBefore, 12)
        XCTAssertEqual(ItemFlow.finish(kind: .gift, path: [.online]).deadlines.first?.daysBefore, 10)
    }

    func testDinnerReservationAndPastDatesBecomeToday() {
        XCTAssertEqual(ItemFlow.question(kind: .dinner, path: [.restaurant], name: "Ada", canShipToThem: false)?.options.map(\.path), [.book, .walkIn])
        let f = ItemFlow.finish(kind: .dinner, path: [.restaurant, .book])
        let dates = ItemFlow.dates(f, due: d(2026, 11, 30), now: d(2026, 11, 22), calendar: cal)
        XCTAssertEqual(dates.first?.date, d(2026, 11, 22), "a book-by date already past becomes today")
    }

    func testWhoGetsWhichStart() {
        XCTAssertTrue(ItemFlow.asksIfKnown(.cake))
        XCTAssertFalse(ItemFlow.asksIfKnown(.other))
        XCTAssertFalse(ItemFlow.handles(.card))
        XCTAssertFalse(ItemFlow.handles(.call))
        XCTAssertEqual(ItemFlow.summary([(label: "Order by", date: d(2026, 12, 12))]), "Order by Dec 12")
    }
}
