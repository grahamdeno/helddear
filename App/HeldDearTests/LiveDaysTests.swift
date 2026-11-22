import XCTest
@testable import HeldDear

/// Lock Screen cards and written lines (Nov 22, 2026).
final class LiveDaysTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))! }

    func testADaysCardShowsTodayForCloseCirclesUntilDone() {
        let now = day(2026, 12, 17, 9)
        let base = LiveDays.Day(id: UUID(), title: "Ada's birthday", dueDate: day(2026, 12, 17), ring: .inner, settled: false, personal: true)
        XCTAssertEqual(LiveDays.days([base], now: now, calendar: cal).count, 1)
        var outer = base; outer.ring = .outer
        var done = base; done.settled = true
        var holiday = base; holiday.personal = false
        var tomorrow = base; tomorrow.dueDate = day(2026, 12, 18)
        XCTAssertTrue(LiveDays.days([outer, done, holiday, tomorrow], now: now, calendar: cal).isEmpty)
    }

    func testArrivalCardsForTheNextTwoDaysUntilReady() {
        let now = day(2026, 12, 13, 9)
        let a = LiveDays.Arrival(id: UUID(), title: "Ada's cake", arrives: day(2026, 12, 15), placed: true, ready: false)
        XCTAssertEqual(LiveDays.arrivals([a], now: now, calendar: cal).count, 1)
        var later = a; later.arrives = day(2026, 12, 16)
        var notOrdered = a; notOrdered.placed = false
        var here = a; here.ready = true
        var past = a; past.arrives = day(2026, 12, 12)
        XCTAssertTrue(LiveDays.arrivals([later, notOrdered, here, past], now: now, calendar: cal).isEmpty)
        XCTAssertEqual(LiveDays.arrivalLine(day(2026, 12, 13), now: now, calendar: cal), "Arrives today")
        XCTAssertEqual(LiveDays.arrivalLine(day(2026, 12, 14), now: now, calendar: cal), "Arrives tomorrow")
    }

    func testAShareLineKeepsPrivateDetailsOut() {
        let facts = PersonFacts(name: "Ada", occasion: .birthday, loves: ["sourdough"], goodToKnow: "Allergic to cats",
                                pastYears: ["Pottery class"])
        let share = IdeaPrompts.lines(.shareLine, facts)
        XCTAssertFalse(share.contains("sourdough"))
        XCTAssertFalse(share.contains("cats"))
        XCTAssertFalse(share.contains("Pottery"))
        XCTAssertTrue(IdeaPrompts.lines(.cardLine, facts).contains("sourdough"))
    }

    func testWrittenLinesAreCleaned() {
        XCTAssertEqual(IdeaPrompts.cleanLine("\"Happy birthday \u{2014} love you\"", kind: .cardLine), "Happy birthday, love you")
        XCTAssertNil(IdeaPrompts.cleanLine(String(repeating: "a", count: 61), kind: .shareLine))
        XCTAssertNil(IdeaPrompts.cleanLine("  ", kind: .cardLine))
    }
}
