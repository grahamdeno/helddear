import XCTest
@testable import HeldDear

/// Shared holidays (Epic 1), suggested parts by relationship (1.6), the free plan limit (2.7) and build switches.
final class HolidayTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func state(_ name: String, occasion: OccasionType = .christmas, due: Date, status: MomentStatus = .upcoming,
               ring: Ring = .inner) -> MomentState {
        MomentState(id: UUID(), personName: name, ring: ring, dueDate: due, status: status, planKind: nil,
                    planDone: false, greetingDone: false, anyActDone: false, openWishCount: 0,
                    hasPhone: true, turning: nil, headsUpAt: nil, occasion: occasion)
    }

    // MARK: 1.4 One heads-up per holiday

    func testHoliday_oneHeadsUpSixWeeksOutAndOneMorningAlert() {
        let now = day(2026, 10, 1, 12)
        let due = day(2026, 12, 25)
        let people = ["Anna", "Sam", "Lily", "Mom", "Ben", "Rose"].map { state($0, due: due) }
        let alerts = AlertPlanner.plan(moments: people, seasons: [], now: now, calendar: cal).alerts
        XCTAssertEqual(alerts.count, 2, "\(alerts.map(\.id))")
        XCTAssertEqual(alerts[0].fireDate, day(2026, 11, 13, 9))
        XCTAssertEqual(alerts[0].body, "Christmas is in 6 weeks. 6 people to plan for.")
        XCTAssertNil(alerts[0].momentID)
        XCTAssertEqual(alerts[1].fireDate, day(2026, 12, 25, 9))
        XCTAssertEqual(alerts[1].body, "Merry Christmas. Held Dear has your messages ready for 6 people.")
    }

    func testHoliday_birthdaysStillGetTheirOwnAlerts() {
        let now = day(2026, 10, 1, 12)
        let alerts = AlertPlanner.plan(moments: [state("Anna", occasion: .birthday, due: day(2026, 12, 2)),
                                                 state("Sam", due: day(2026, 12, 25))],
                                       seasons: [], now: now, calendar: cal).alerts
        XCTAssertTrue(alerts.contains { $0.kind == .headsUp && $0.body.hasPrefix("Anna's birthday") })
        XCTAssertTrue(alerts.contains { $0.id.hasPrefix("holiday-christmas-2026") })
        XCTAssertFalse(alerts.contains { $0.body.contains("Christmas for Sam") })
    }

    func testHoliday_pastHeadsUpIsNotRepeated() {
        let now = day(2026, 12, 1, 12)
        let alerts = AlertPlanner.plan(moments: [state("Anna", due: day(2026, 12, 25))], seasons: [], now: now, calendar: cal).alerts
        XCTAssertEqual(alerts.map(\.id), ["holiday-dayof-christmas-2026"])
    }

    func testHoliday_notCountedInBusySeasons() {
        let now = day(2026, 10, 1, 12)
        let due = day(2026, 12, 25)
        let seasons = AlertPlanner.seasons(from: ["A", "B", "C", "D"].map { state($0, due: due) }, now: now, calendar: cal)
        XCTAssertTrue(seasons.isEmpty)
    }

    // MARK: 1.2 Holiday page words

    func testHoliday_sublineAndSummary() {
        XCTAssertEqual(Holidays.subline(daysLeft: 35, people: 5), "In 35 days, for 5 people")
        XCTAssertEqual(Holidays.subline(daysLeft: 1, people: 1), "Tomorrow, for 1 person")
        XCTAssertEqual(Holidays.subline(daysLeft: 0, people: 3), "Today, for 3 people")
        XCTAssertEqual(Holidays.summary(peopleReady: 1, people: 5, thingsReady: 2, things: 12),
                       "1 of 5 people ready · 2 of 12 things ready")
        XCTAssertEqual(Holidays.summary(peopleReady: 0, people: 2, thingsReady: 0, things: 0), "Nothing planned yet")
    }

    func testHoliday_nextUpIsTheLeastReadyThenByName() {
        let people: [(name: String, ready: Int, total: Int)] = [("Anna", 2, 4), ("Ben", 0, 1), ("Sam", 2, 2), ("Mom", 0, 2)]
        XCTAssertEqual(Holidays.nextUp(people), 1, "Ben and Mom both have none ready; Ben comes first by name")
        XCTAssertNil(Holidays.nextUp([("Sam", 2, 2)]))
    }

    // MARK: 1.5 Choose your holidays

    func testHoliday_enabledDefaultsToAllOfferedAndValentinesIsHidden() {
        let d = UserDefaults(suiteName: "HolidayTests-\(UUID())")!
        XCTAssertEqual(Holidays.enabled(d), [.christmas, .mothersDay, .fathersDay])
        Holidays.setEnabled(.fathersDay, false, d)
        XCTAssertEqual(Holidays.enabled(d), [.christmas, .mothersDay])
        Holidays.setEnabled(.valentines, true, d)
        XCTAssertFalse(Holidays.enabled(d).contains(.valentines))
    }

    // MARK: 1.6 Suggested parts by relationship

    func testSuggestions_christmasStartByRelationship() {
        func titles(_ r: String?) -> [String] { PartSuggestions.holidayStart(for: .christmas, relationship: r).map(\.title) }
        XCTAssertEqual(titles("Wife"), ["Gift", "Stocking", "Card", "Gift from the kids"])
        XCTAssertEqual(titles("daughter"), ["Gift", "From Santa", "Stocking"])
        XCTAssertEqual(titles("Mother"), ["Gift", "Card"])
        XCTAssertEqual(titles("Grandfather"), ["Gift", "Card"])
        XCTAssertEqual(titles("Brother"), ["Gift"])
        XCTAssertEqual(titles("Sister-in-law"), ["Gift"])
        XCTAssertEqual(titles("Teacher"), ["Card"])
        XCTAssertEqual(titles(nil), ["Gift", "Card"])
        XCTAssertEqual(PartSuggestions.holidayStart(for: .mothersDay, relationship: "Mother").map(\.title), ["Gift", "Card"])
    }

    func testSuggestions_christmasAddListHasTheHolidayKinds() {
        let kinds = PartSuggestions.suggestions(for: .christmas, relationship: nil).map(\.kind)
        XCTAssertEqual(kinds, [.gift, .stocking, .fromSanta, .card, .kidsMade, .theDay])
    }

    func testRelationship_groups() {
        XCTAssertEqual(Relationship.group("Husband"), .partner)
        XCTAssertEqual(Relationship.group(" son "), .child)
        XCTAssertEqual(Relationship.group("Grandma"), .parent)
        XCTAssertEqual(Relationship.group("In-law"), .sibling)
        XCTAssertEqual(Relationship.group("Cousin"), .extended)
        XCTAssertEqual(Relationship.group("Coach"), .community)
        XCTAssertEqual(Relationship.group(""), .unknown)
        XCTAssertEqual(Relationship.group(nil), .unknown)
    }

    // MARK: 2.7 Free plan limit

    func testPlanLimit_threePeopleFreeThenLifetime() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        XCTAssertTrue(PlanLimit.allows(personID: c, plannedPeople: [a, b], hasLifetime: false))
        XCTAssertTrue(PlanLimit.allows(personID: a, plannedPeople: [a, b, c], hasLifetime: false), "Already planned stays free")
        XCTAssertFalse(PlanLimit.allows(personID: d, plannedPeople: [a, b, c], hasLifetime: false))
        XCTAssertTrue(PlanLimit.allows(personID: d, plannedPeople: [a, b, c], hasLifetime: true))
    }

    // MARK: Repeatable parts (feedback on build 1010)

    func testSuggestions_giftsAndKidsGiftsCanBeAddedAgain() {
        let list = PartSuggestions.suggestions(for: .birthday, relationship: "Wife")
        let kids = list.first { $0.kind == .kidsMade }!
        let gift = list.first { $0.kind == .gift }!
        let cake = list.first { $0.kind == .cake }!
        let breakfast = list.first { $0.label == "Breakfast in bed" }!
        XCTAssertTrue(PartSuggestions.canAddAgain(kids))
        XCTAssertTrue(PartSuggestions.canAddAgain(gift))
        XCTAssertFalse(PartSuggestions.canAddAgain(cake))
        XCTAssertFalse(PartSuggestions.canAddAgain(breakfast))
        let parts: [(kindRaw: String, label: String?)] = [("kidsMade", nil), ("kidsMade", nil), ("cake", nil)]
        XCTAssertEqual(PartSuggestions.count(kids, parts: parts), 2)
    }

    func testOwners_kidsGiftNamesWhoItsFrom() {
        XCTAssertNil(PartOwners.kidsGiftName(names: []))
        XCTAssertEqual(PartOwners.kidsGiftName(names: ["Sam"]), "Gift from Sam")
        XCTAssertEqual(PartOwners.kidsGiftName(names: ["Lily", "Rose"]), "Gift from Lily and Rose")
    }

    func testOwners_householdIsPartnerAndChildrenNotParents() {
        XCTAssertTrue(Relationship.isHouseholdGiver(relationship: "Wife", isInner: false))
        XCTAssertTrue(Relationship.isHouseholdGiver(relationship: "Daughter", isInner: true))
        XCTAssertFalse(Relationship.isHouseholdGiver(relationship: "Mother", isInner: true), "Inner ring, but not household")
        XCTAssertTrue(Relationship.isHouseholdGiver(relationship: nil, isInner: true), "Unknown and inner: offered until set")
        XCTAssertFalse(Relationship.isHouseholdGiver(relationship: nil, isInner: false))
    }

    // MARK: R2, R3 build switches

    func testBuildSwitches_offInTestBuilds() {
        XCTAssertFalse(AppFeatures.serverFeatures, "Mailed cards and family pages are off in 1.0 builds")
        XCTAssertFalse(AppFeatures.testFlightTools, "Only testflight.yml compiles the TestFlight tools in")
    }
}
