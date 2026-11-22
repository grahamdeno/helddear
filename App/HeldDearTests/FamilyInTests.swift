import XCTest
@testable import HeldDear

/// "Get the family in" (Nov 22, 2026): when it shows, the texts, the named send button, the list kept on the phone,
/// and the two alerts.
final class FamilyInTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func state(familyOn: Bool = true) -> MomentState {
        var s = MomentState(id: UUID(), personName: "Ada", ring: .inner, dueDate: day(2027, 1, 9), status: .upcoming,
                            planKind: nil, planDone: false, greetingDone: false, anyActDone: false, openWishCount: 0,
                            hasPhone: true, turning: nil, headsUpAt: nil)
        s.familyOn = familyOn
        return s
    }

    func testOnForInnerCircleUnlessChanged() {
        XCTAssertTrue(FamilyIn.isOn(ring: .inner, override: nil))
        XCTAssertFalse(FamilyIn.isOn(ring: .middle, override: nil))
        XCTAssertFalse(FamilyIn.isOn(ring: .inner, override: false))
        XCTAssertTrue(FamilyIn.isOn(ring: .outer, override: true))
    }

    func testPersonalDaysOnly() {
        XCTAssertTrue(FamilyIn.applies(to: .birthday))
        XCTAssertTrue(FamilyIn.applies(to: .anniversary))
        XCTAssertFalse(FamilyIn.applies(to: .christmas))
        XCTAssertFalse(FamilyIn.applies(to: .mothersDay))
    }

    func testSuggestionWindow() {
        XCTAssertFalse(FamilyIn.showsSuggestion(daysLeft: 15, on: true, handled: false))
        XCTAssertTrue(FamilyIn.showsSuggestion(daysLeft: 14, on: true, handled: false))
        XCTAssertTrue(FamilyIn.showsSuggestion(daysLeft: 2, on: true, handled: false))
        XCTAssertFalse(FamilyIn.showsSuggestion(daysLeft: 1, on: true, handled: false))
        XCTAssertFalse(FamilyIn.showsSuggestion(daysLeft: 10, on: false, handled: false))
        XCTAssertFalse(FamilyIn.showsSuggestion(daysLeft: 10, on: true, handled: true))
    }

    func testOneFollowUpOnlyAfterACardReminder() {
        XCTAssertTrue(FamilyIn.showsFollowUp(daysLeft: 3, cardAskSent: true, followedUp: false))
        XCTAssertFalse(FamilyIn.showsFollowUp(daysLeft: 4, cardAskSent: true, followedUp: false))
        XCTAssertFalse(FamilyIn.showsFollowUp(daysLeft: 3, cardAskSent: false, followedUp: false))
        XCTAssertFalse(FamilyIn.showsFollowUp(daysLeft: 2, cardAskSent: true, followedUp: true))
        XCTAssertFalse(FamilyIn.showsFollowUp(daysLeft: 0, cardAskSent: true, followedUp: false))
    }

    func testSendButtonNamesEveryone() {
        XCTAssertEqual(FamilyIn.sendTitle([]), "Choose who to text")
        XCTAssertEqual(FamilyIn.sendTitle(["Bo"]), "Text Bo")
        XCTAssertEqual(FamilyIn.sendTitle(["Bo", "Cy"]), "Text Bo and Cy")
        XCTAssertEqual(FamilyIn.sendTitle(["Bo", "Cy", "Di"]), "Text Bo, Cy and Di")
        XCTAssertEqual(FamilyIn.sendTitle(["Bo", "Cy", "Di", "Ed", "Fy"]), "Text Bo, Cy and 3 others")
    }

    func testTexts() {
        let date = day(2027, 1, 9, 12)
        let card = FamilyIn.cardText(subject: "Ada's birthday", name: "Ada", date: date, address: "1 Elm St\nTown, NC 28401")
        XCTAssertTrue(card.hasPrefix("Ada's birthday is Saturday, January 9. A card from you would mean a lot."))
        XCTAssertTrue(card.hasSuffix("Ada's address: 1 Elm St, Town, NC 28401"))
        XCTAssertFalse(FamilyIn.cardText(subject: "Ada's birthday", name: "Ada", date: date, address: nil).contains("address"))
        let notes = FamilyIn.notesText(subject: "Ada's birthday", name: "Ada", date: date, link: "https://example.com/p/x")
        XCTAssertTrue(notes.hasSuffix("https://example.com/p/x"))
        XCTAssertTrue(notes.contains("Ada sees them all on the day."))
    }

    func testOnlyPeopleWithANumberCanBeTexted() {
        let list = [FamilyIn.Recipient(id: "1", name: "Bo", phone: "555"), FamilyIn.Recipient(id: "2", name: "Cy", phone: nil),
                    FamilyIn.Recipient(id: "3", name: "Di", phone: "")]
        XCTAssertEqual(FamilyIn.textable(list).map(\.id), ["1"])
    }

    func testListIsKeptPerPersonWithoutDuplicates() {
        let d = UserDefaults(suiteName: "FamilyInTests")!
        d.removePersistentDomain(forName: "FamilyInTests")
        let circle = FamilyCircle(defaults: d)
        let person = UUID(), other = UUID()
        circle.add([.init(id: "1", name: "Bo", phone: "555")], for: person)
        circle.add([.init(id: "1", name: "Bo", phone: "555"), .init(id: "9", name: "Bo again", phone: "555"),
                    .init(id: "2", name: "Cy", phone: "556")], for: person)
        XCTAssertEqual(circle.recipients(for: person).map(\.id), ["1", "2"])
        XCTAssertTrue(circle.recipients(for: other).isEmpty)
        let m = UUID()
        XCTAssertFalse(circle.record(for: m).handled)
        circle.update(m) { $0.choice = .card }
        XCTAssertTrue(circle.record(for: m).handled)
        circle.setOn(false, for: person)
        XCTAssertEqual(circle.override(for: person), false)
    }

    func testAlerts() {
        let now = day(2026, 11, 22, 12)
        var m = state()
        var alerts = AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal).alerts
        let prompt = alerts.first { $0.kind == .familyPrompt }
        XCTAssertEqual(prompt?.fireDate, day(2026, 12, 26, 9))
        XCTAssertEqual(prompt?.body, "Two weeks to Ada's birthday. Get the family in?")
        XCTAssertFalse(alerts.contains { $0.kind == .familyFollowUp })

        m.familyHandled = true
        m.familyCardAsked = true
        alerts = AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal).alerts
        XCTAssertFalse(alerts.contains { $0.kind == .familyPrompt })
        XCTAssertEqual(alerts.first { $0.kind == .familyFollowUp }?.fireDate, day(2027, 1, 6, 9))

        m.familyFollowedUp = true
        XCTAssertFalse(AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal).alerts.contains { $0.kind == .familyFollowUp })
        XCTAssertFalse(AlertPlanner.plan(moments: [state(familyOn: false)], seasons: [], now: now, calendar: cal).alerts
            .contains { $0.kind == .familyPrompt })
    }
}
