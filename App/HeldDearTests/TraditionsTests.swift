import XCTest
@testable import HeldDear

/// Holiday traditions (Nov 22, 2026): added once per day, only for the people chosen, not after being turned off.
final class TraditionsTests: XCTestCase {
    func testAddedOncePerDayForChosenPeople() {
        let kid1 = UUID(), kid2 = UUID(), aunt = UUID()
        let d1 = UUID(), d2 = UUID(), d3 = UUID()
        var t = Tradition(holiday: "christmas", name: "Ornament", recipientIDs: [kid1, kid2])
        let days = [(dayID: d1, personID: kid1), (dayID: d2, personID: kid2), (dayID: d3, personID: aunt)]
        XCTAssertEqual(Traditions.toAdd(t, days: days), [d1, d2])
        t.applied = [d1]
        XCTAssertEqual(Traditions.toAdd(t, days: days), [d2], "already added days stay out, even if removed from a plan")
        t.on = false
        XCTAssertTrue(Traditions.toAdd(t, days: days).isEmpty)
        t.on = true; t.name = "  "
        XCTAssertTrue(Traditions.toAdd(t, days: days).isEmpty)
    }

    func testKeptAndChanged() {
        let d = UserDefaults(suiteName: "TraditionsTests")!
        d.removePersistentDomain(forName: "TraditionsTests")
        var t = Tradition(holiday: "christmas", name: "Ornament")
        Traditions.upsert(t, d)
        t.name = "Christmas ornament"
        Traditions.upsert(t, d)
        XCTAssertEqual(Traditions.all(d).map(\.name), ["Christmas ornament"])
        XCTAssertEqual(Traditions.forHoliday("christmas", d).count, 1)
        XCTAssertTrue(Traditions.forHoliday("valentines", d).isEmpty)
        Traditions.remove(t.id, d)
        XCTAssertTrue(Traditions.all(d).isEmpty)
    }
}
