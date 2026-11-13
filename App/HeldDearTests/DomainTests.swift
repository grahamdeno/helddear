import XCTest
@testable import HeldDear

final class DomainTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: Dates

    func testFeb29ObservedOnFeb28InNonLeapYears() {
        XCTAssertEqual(OccasionDates.date(month: 2, day: 29, year: 2027, calendar: cal), day(2027, 2, 28))
        XCTAssertEqual(OccasionDates.date(month: 2, day: 29, year: 2028, calendar: cal), day(2028, 2, 29))
    }

    func testOccurrencesCoverTwelveMonthsAndRecentPast() {
        let now = day(2026, 11, 11, 10)
        let next = OccasionDates.occurrences(month: 3, day: 3, from: now, calendar: cal)
        XCTAssertEqual(next.map(\.year), [2027])
        let justPassed = OccasionDates.occurrences(month: 11, day: 9, from: now, calendar: cal)
        XCTAssertEqual(justPassed.map(\.year), [2026], "2 days ago stays in the window for F1")
        let longPassed = OccasionDates.occurrences(month: 11, day: 1, from: now, calendar: cal)
        XCTAssertEqual(longPassed.map(\.year), [2027])
    }

    func testCountdownWording() {
        let now = day(2026, 11, 11, 15)
        XCTAssertEqual(OccasionDates.countdown(to: day(2026, 11, 11), from: now, calendar: cal), "Today")
        XCTAssertEqual(OccasionDates.countdown(to: day(2026, 11, 20), from: now, calendar: cal), "in 9 days")
        XCTAssertEqual(OccasionDates.countdown(to: day(2026, 11, 10), from: now, calendar: cal), "Yesterday")
        XCTAssertEqual(OccasionDates.countdown(to: day(2027, 1, 14), from: now, calendar: cal), "in 2 months")
    }

    func testNextMorning() {
        XCTAssertEqual(OccasionDates.nextMorning(after: day(2026, 11, 11, 8), calendar: cal), day(2026, 11, 11, 9))
        XCTAssertEqual(OccasionDates.nextMorning(after: day(2026, 11, 11, 10), calendar: cal), day(2026, 11, 12, 9))
    }

    // MARK: Parsers

    func testBirthdayParser() {
        XCTAssertEqual(BirthdayParser.parse("Mike, March 3"), ParsedBirthday(name: "Mike", month: 3, day: 3, year: nil))
        XCTAssertEqual(BirthdayParser.parse("March 3 Mike"), ParsedBirthday(name: "Mike", month: 3, day: 3, year: nil))
        XCTAssertEqual(BirthdayParser.parse("Mike 3/3"), ParsedBirthday(name: "Mike", month: 3, day: 3, year: nil))
        XCTAssertEqual(BirthdayParser.parse("Aunt Jo's birthday is Dec 2nd, 1956"),
                       ParsedBirthday(name: "Aunt Jo", month: 12, day: 2, year: 1956))
        XCTAssertEqual(BirthdayParser.parse("Nora 7 May"), ParsedBirthday(name: "Nora", month: 5, day: 7, year: nil))
        XCTAssertNil(BirthdayParser.parse("Mike"))
        XCTAssertNil(BirthdayParser.parse("March 3"))
        XCTAssertNil(BirthdayParser.parse("Mike, February 31"))
    }

    func testWishParser() {
        let names = ["Nora", "Mom", "Nora Lee"]
        let a = WishParser.parse("Nora wants blue skates", names: names)
        XCTAssertEqual(a.index, 0); XCTAssertEqual(a.text, "blue skates")
        let b = WishParser.parse("Nora Lee would like a tent", names: names)
        XCTAssertEqual(b.index, 2); XCTAssertEqual(b.text, "a tent")
        let c = WishParser.parse("Mom: gardening gloves", names: names)
        XCTAssertEqual(c.index, 1); XCTAssertEqual(c.text, "gardening gloves")
        let d = WishParser.parse("Someone wants socks", names: names)
        XCTAssertNil(d.index); XCTAssertEqual(d.text, "Someone wants socks")
        XCTAssertNil(WishParser.parse("Momentum shoes", names: names).index)
    }

    // MARK: Alerts

    func state(_ name: String = "Mom", ring: Ring = .inner, due: Date, status: MomentStatus = .upcoming,
               wishes: Int = 0, plan: ActKind? = nil, planDone: Bool = false, phone: Bool = true,
               headsUpAt: Date? = nil) -> MomentState {
        MomentState(id: UUID(), personName: name, ring: ring, dueDate: due, status: status, planKind: plan,
                    planDone: planDone, greetingDone: false, anyActDone: planDone, openWishCount: wishes,
                    hasPhone: phone, turning: nil, headsUpAt: headsUpAt)
    }

    func testInnerRingGetsFullSequence() {
        let now = day(2026, 9, 1, 12)
        let m = state(due: day(2026, 12, 2))
        let result = AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal)
        let kinds = result.alerts.map(\.kind)
        XCTAssertEqual(kinds, [.wishPrompt, .headsUp, .nudge, .nudge, .dayOf, .missed])
        XCTAssertEqual(result.alerts[1].fireDate, day(2026, 11, 11, 9))
        XCTAssertEqual(result.alerts[1].body, "Mom's birthday is in 3 weeks.")
        XCTAssertEqual(result.alerts[4].fireDate, day(2026, 12, 2, 9))
        XCTAssertEqual(result.headsUpUpdates[m.id], day(2026, 11, 11, 9))
    }

    func testWishPromptSkippedWhenWishesSaved() {
        let now = day(2026, 9, 1, 12)
        let m = state(due: day(2026, 12, 2), wishes: 2)
        let alerts = AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal).alerts
        XCTAssertFalse(alerts.contains { $0.kind == .wishPrompt })
        XCTAssertEqual(alerts.first { $0.kind == .headsUp }?.body, "Mom's birthday is in 3 weeks. You saved 2 ideas.")
    }

    func testAddedCloserThanLeadTimeFiresNextMorning() {
        let now = day(2026, 11, 20, 14)
        let m = state(due: day(2026, 12, 2))
        let result = AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal)
        XCTAssertEqual(result.alerts.first { $0.kind == .headsUp }?.fireDate, day(2026, 11, 21, 9))
    }

    func testHeadsUpNotRepeatedOnceDelivered() {
        let now = day(2026, 11, 20, 14)
        let m = state(due: day(2026, 12, 2), headsUpAt: day(2026, 11, 11, 9))
        let result = AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal)
        XCTAssertFalse(result.alerts.contains { $0.kind == .headsUp })
        XCTAssertNil(result.headsUpUpdates[m.id])
        XCTAssertFalse(result.alerts.contains { $0.kind == .nudge }, "both nudges are past")
    }

    func testOuterRingOnlyDayOfAndMissed() {
        let now = day(2026, 11, 1, 12)
        let m = state("Kris", ring: .outer, due: day(2026, 11, 30))
        let kinds = AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal).alerts.map(\.kind)
        XCTAssertEqual(kinds, [.dayOf, .missed])
    }

    func testCutoffReminderForUnfinishedGift() {
        let now = day(2026, 11, 15, 12)
        let m = state(due: day(2026, 12, 2), status: .planning, plan: .gift)
        let alerts = AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal).alerts
        XCTAssertEqual(alerts.first { $0.kind == .cutoff }?.fireDate, day(2026, 11, 27, 9))
    }

    func testDayOfCategoryAndText() {
        var m = state(due: day(2026, 12, 2), status: .planning, plan: .gift, planDone: true)
        m.turning = 70
        XCTAssertEqual(AlertPlanner.dayOfText(m), "It's Mom's birthday. Turning 70 today. Your gift is on its way.")
        XCTAssertEqual(AlertPlanner.dayOfCategory(m), NotificationCategory.dayOfMessage)
        let call = state(due: day(2026, 12, 2), status: .planning, plan: .call)
        XCTAssertEqual(AlertPlanner.dayOfCategory(call), NotificationCategory.dayOfCall)
        let noPhone = state(due: day(2026, 12, 2), phone: false)
        XCTAssertEqual(AlertPlanner.dayOfCategory(noPhone), NotificationCategory.dayOfOpen)
    }

    func testNoMissedAlertWhenSomethingWasDone() {
        let now = day(2026, 11, 15, 12)
        let m = state(due: day(2026, 12, 2), status: .done, plan: .gift, planDone: true)
        XCTAssertTrue(AlertPlanner.plan(moments: [m], seasons: [], now: now, calendar: cal).alerts.isEmpty)
    }

    func testSameDayHeadsUpsAreGrouped() {
        let now = day(2026, 11, 1, 12)
        let a = state("Mom", due: day(2026, 12, 2))
        let b = state("Dan", due: day(2026, 12, 2))
        let alerts = AlertPlanner.plan(moments: [a, b], seasons: [], now: now, calendar: cal).alerts
        let grouped = alerts.filter { $0.kind == .grouped }
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped.first?.body, "2 birthdays coming up: Dan and Mom.")
        XCTAssertFalse(alerts.contains { $0.kind == .headsUp })
    }

    func testSeasonsNeedThreeInnerOrMiddle() {
        let now = day(2026, 10, 1, 12)
        let ms = [state("Mom", due: day(2026, 12, 2)), state("Dan", ring: .middle, due: day(2026, 12, 9)),
                  state("Leo", ring: .middle, due: day(2026, 12, 18)), state("Kris", ring: .outer, due: day(2026, 12, 30)),
                  state("Jess", due: day(2027, 1, 4))]
        let seasons = AlertPlanner.seasons(from: ms, now: now, calendar: cal)
        XCTAssertEqual(seasons.count, 1)
        XCTAssertEqual(seasons[0].monthStart, day(2026, 12, 1))
        let alerts = AlertPlanner.plan(moments: [], seasons: seasons, now: now, calendar: cal).alerts
        XCTAssertEqual(alerts.first?.fireDate, day(2026, 11, 10, 9))
        XCTAssertEqual(alerts.first?.body, "December is a big month. 3 of your people have birthdays in it.")
    }

    func testAlertCapIsRespected() {
        let now = day(2026, 1, 1, 12)
        let many = (0..<40).map { i in state("P\(i)", due: OccasionDates.adding(days: 70 + i, to: day(2026, 1, 1), calendar: cal)) }
        XCTAssertEqual(AlertPlanner.plan(moments: many, seasons: [], now: now, calendar: cal).alerts.count, AlertPlanner.maxAlerts)
    }
}

extension DomainTests {
    func testNextDate() {
        XCTAssertEqual(OccasionDates.nextDate(month: 11, day: 11, onOrAfter: day(2026, 11, 11, 15), calendar: cal), day(2026, 11, 11))
        XCTAssertEqual(OccasionDates.nextDate(month: 11, day: 10, onOrAfter: day(2026, 11, 11, 15), calendar: cal), day(2027, 11, 10))
    }
}

extension DomainTests {
    func testNextActFollowsState() {
        let now = day(2026, 11, 12, 8)
        let due = day(2026, 12, 9)
        XCTAssertEqual(NextAct.make(state(due: due), now: now, calendar: cal), .pick)
        XCTAssertEqual(NextAct.make(state(due: day(2027, 4, 1)), now: now, calendar: cal), .saveWish)
        XCTAssertEqual(NextAct.make(state(due: due, status: .planning, plan: .gift), now: now, calendar: cal), .orderBy(day(2026, 12, 4)))
        XCTAssertEqual(NextAct.make(state(due: due, status: .planning, plan: .card), now: now, calendar: cal), .mailBy(day(2026, 12, 4)))
        XCTAssertEqual(NextAct.make(state(due: due, status: .done, plan: .gift, planDone: true), now: now, calendar: cal), .allSet)
        XCTAssertEqual(NextAct.make(state(due: day(2026, 11, 12)), now: now, calendar: cal), .dayOfMessage)
        XCTAssertEqual(NextAct.make(state(due: day(2026, 11, 12), status: .planning, plan: .call), now: now, calendar: cal), .dayOfCall)
        XCTAssertEqual(NextAct.make(state(due: day(2026, 11, 11), status: .missed), now: now, calendar: cal), .lateNote)
        XCTAssertEqual(NextAct.pick.title(name: "Mom"), "Pick what to do")
        XCTAssertEqual(NextAct.dayOfMessage.title(name: "Mom"), "Send Mom a message")
    }

    func testHeroPrefersMissedThenSoonest() {
        let now = day(2026, 11, 12, 8)
        let soon = state("Dan", due: day(2026, 11, 20))
        let later = state("Mom", due: day(2026, 12, 9))
        XCTAssertEqual(HeroPicker.pick([later, soon], now: now, calendar: cal)?.personName, "Dan")
        let missed = state("Kris", due: day(2026, 11, 11), status: .missed)
        XCTAssertEqual(HeroPicker.pick([later, soon, missed], now: now, calendar: cal)?.personName, "Kris")
        let settled = state("Leo", due: day(2026, 11, 10), status: .letGo)
        XCTAssertEqual(HeroPicker.pick([settled, later], now: now, calendar: cal)?.personName, "Mom")
    }
}

extension DomainTests {
    func testScheduleForInnerRing() {
        let stops = AlertPlanner.schedule(for: state(due: day(2026, 12, 9), status: .planning, plan: .card), calendar: cal)
        XCTAssertTrue(stops.contains { $0.label == "Mail by, for the card" && $0.date == day(2026, 12, 4, 9) })
        XCTAssertTrue(stops.contains { $0.label == "A message ready" && $0.date == day(2026, 12, 9, 9) })
        let upcoming = AlertPlanner.schedule(for: state(due: day(2026, 12, 9)), calendar: cal)
        XCTAssertEqual(upcoming.map(\.label), ["A question about wishes", "A heads-up and a plan", "A message ready"])
        let outer = AlertPlanner.schedule(for: state(ring: .outer, due: day(2026, 12, 9)), calendar: cal)
        XCTAssertEqual(outer.map(\.label), ["A message ready"])
    }
}

final class PhotoWindowsTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func testSkipsThisYearWhenBirthdayIsAhead() {
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 12))!
        let w = PhotoWindows.birthdays(month: 12, day: 9, now: now, yearsBack: 3, calendar: cal)
        XCTAssertEqual(w.map(\.year), [2025, 2024, 2023])
        XCTAssertEqual(cal.dateComponents([.month, .day], from: w[0].start), DateComponents(month: 12, day: 8))
        XCTAssertEqual(cal.dateComponents([.month, .day], from: w[0].end), DateComponents(month: 12, day: 11))
    }

    func testIncludesThisYearWhenPassedAndLeapDay() {
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 12))!
        let w = PhotoWindows.birthdays(month: 2, day: 29, now: now, yearsBack: 1, calendar: cal)
        XCTAssertEqual(w.map(\.year), [2026, 2025])
        XCTAssertEqual(cal.dateComponents([.month, .day], from: w[0].start), DateComponents(month: 2, day: 27))
    }
}

final class OccasionRulesTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func ymd(_ d: Date) -> DateComponents { cal.dateComponents([.year, .month, .day], from: d) }

    func testMothersAndFathersDay2027() {
        XCTAssertEqual(ymd(OccasionRules.date(type: .mothersDay, month: 0, day: 0, year: 2027, calendar: cal)!),
                       DateComponents(year: 2027, month: 5, day: 9))
        XCTAssertEqual(ymd(OccasionRules.date(type: .fathersDay, month: 0, day: 0, year: 2027, calendar: cal)!),
                       DateComponents(year: 2027, month: 6, day: 20))
    }

    func testChristmasIgnoresStoredDate() {
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 12))!
        let o = OccasionRules.occurrences(type: .christmas, month: 1, day: 1, year: nil, from: now, calendar: cal)
        XCTAssertEqual(o.count, 1)
        XCTAssertEqual(ymd(o[0].date), DateComponents(year: 2026, month: 12, day: 25))
    }

    func testOneTimeEventOnlyInItsYear() {
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 12))!
        XCTAssertEqual(OccasionRules.occurrences(type: .graduation, month: 5, day: 20, year: 2027, from: now, calendar: cal).map(\.year), [2027])
        XCTAssertTrue(OccasionRules.occurrences(type: .graduation, month: 5, day: 20, year: 2026, from: now, calendar: cal).isEmpty)
        XCTAssertTrue(OccasionRules.occurrences(type: .newHome, month: 5, day: 20, year: nil, from: now, calendar: cal).isEmpty)
    }

    func testWordsAndCounts() {
        XCTAssertEqual(OccasionType.anniversary.subject(name: "Mom", partner: "Dad"), "Mom & Dad's anniversary")
        XCTAssertEqual(OccasionType.anniversary.countLine(OccasionRules.count(type: .anniversary, startYear: 1986, occurrenceYear: 2026)),
                       "40th anniversary")
        XCTAssertEqual(OccasionType.ordinal(11), "11th")
        XCTAssertEqual(OccasionType.ordinal(22), "22nd")
        XCTAssertEqual(OccasionType.christmas.greeting(name: "Mom"), "Merry Christmas, Mom!")
        XCTAssertNil(OccasionType.christmas.countLine(3))
    }
}
