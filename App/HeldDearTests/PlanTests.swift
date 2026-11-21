import XCTest
import SwiftData
@testable import HeldDear

/// Occasion plan (roadmap Epic 2, stories 2.1 to 2.4, amendments A to D). Test names start with the criterion they
/// cover: Suggest (2.1), Owners (2.2), Steps (2.3), Nudge (2.4), A (kinds), B (safe deletes), C (setStep), D (Home).
final class PlanTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: Suggest (2.1)

    func testSuggest_partnerBirthdayHasTheLongList() {
        for word in ["wife", "husband", "spouse", "partner", "Wife", " Partner "] {
            let list = PartSuggestions.suggestions(for: .birthday, relationship: word)
            XCTAssertEqual(list.map(\.title),
                           ["Gift", "Card", "Cake", "Flowers", "Dinner out", "Gift from the kids", "Breakfast in bed"], word)
        }
    }

    func testSuggest_anyOtherOrUnknownRelationshipHasTheShortList() {
        for rel in [nil, "", "mother", "son", "friend"] as [String?] {
            XCTAssertEqual(PartSuggestions.suggestions(for: .birthday, relationship: rel).map(\.title),
                           ["Gift", "Card", "Cake", "The day"], rel ?? "nil")
        }
        XCTAssertEqual(PartSuggestions.suggestions(for: .anniversary, relationship: "wife").map(\.title),
                       ["Gift", "Card", "Cake", "The day"], "Only a partner's birthday has the long list")
    }

    func testSuggest_eachSuggestionMakesItsKind() {
        let list = PartSuggestions.suggestions(for: .birthday, relationship: "wife")
        let kinds = Dictionary(uniqueKeysWithValues: list.map { ($0.title, $0.kind) })
        XCTAssertEqual(kinds["Gift"], .gift)
        XCTAssertEqual(kinds["Card"], .card)
        XCTAssertEqual(kinds["Cake"], .cake)
        XCTAssertEqual(kinds["Flowers"], .flowers)
        XCTAssertEqual(kinds["Dinner out"], .dinner)
        XCTAssertEqual(kinds["Gift from the kids"], .kidsMade)
        XCTAssertEqual(kinds["Breakfast in bed"], .theDay)
        XCTAssertEqual(list.first { $0.title == "Breakfast in bed" }?.label, "Breakfast in bed")
        let short = PartSuggestions.suggestions(for: .birthday, relationship: nil)
        XCTAssertEqual(short.first { $0.title == "The day" }?.kind, .theDay)
        XCTAssertNil(short.first { $0.title == "The day" }?.label)
    }

    func testSuggest_existingPartsShowAdded() {
        let list = PartSuggestions.suggestions(for: .birthday, relationship: "wife")
        let parts: [(kindRaw: String, label: String?)] = [("cake", nil), ("theDay", "Breakfast in bed")]
        let added = list.filter { PartSuggestions.isAdded($0, parts: parts) }.map(\.title)
        XCTAssertEqual(added, ["Cake", "Breakfast in bed"])
        XCTAssertFalse(PartSuggestions.isAdded(list[0], parts: [("theDay", "Picnic")]))
        let day = PartSuggestions.Suggestion(title: "Breakfast in bed", kind: .theDay, label: "Breakfast in bed")
        XCTAssertFalse(PartSuggestions.isAdded(day, parts: [("theDay", "Picnic")]), "A different day part is not this one")
    }

    func testSuggest_relationLineLeavesOutWhatIsUnknown() {
        XCTAssertEqual(PlanReadiness.relationLine(relationship: "Wife", turning: 40), "Your wife, turning 40")
        XCTAssertEqual(PlanReadiness.relationLine(relationship: "wife", turning: nil), "Your wife")
        XCTAssertEqual(PlanReadiness.relationLine(relationship: nil, turning: 40), "Turning 40")
        XCTAssertNil(PlanReadiness.relationLine(relationship: nil, turning: nil))
        XCTAssertNil(PlanReadiness.relationLine(relationship: "  ", turning: nil))
    }

    func testSuggest_readinessWords() {
        XCTAssertEqual(PlanReadiness.summary(ready: 2, total: 6, subject: "Anna's birthday"), "2 of 6 ready")
        XCTAssertEqual(PlanReadiness.summary(ready: 6, total: 6, subject: "Anna's birthday"), "Ready for Anna's birthday")
        XCTAssertEqual(PlanReadiness.summary(ready: 0, total: 0, subject: "Anna's birthday"), "0 of 0 ready")
        let counts = PlanReadiness.counts([(.buy, "wrapped"), (.card, "idea"), (.orderAhead, "open"), (.other, "ready")])
        XCTAssertEqual(counts.ready, 2)
        XCTAssertEqual(counts.total, 4)
    }

    func testSuggest_progressDrawsReadyStartedAndNotStarted() {
        XCTAssertEqual(PartSteps.progress(step: "open", family: .buy), .notStarted)
        XCTAssertEqual(PartSteps.progress(step: "bought", family: .buy), .started)
        XCTAssertEqual(PartSteps.progress(step: "wrapped", family: .buy), .ready)
        XCTAssertEqual(PartSteps.progress(step: "ordered", family: .orderAhead), .started)
        XCTAssertEqual(PartSteps.progress(step: "ready", family: .orderAhead), .ready)
    }

    func testSuggest_rowWordsAndVoiceOverLabel() {
        XCTAssertEqual(PartOwners.rowSubtitle(owner: "You", note: nil), "You")
        XCTAssertEqual(PartOwners.rowSubtitle(owner: "You", note: "  "), "You")
        XCTAssertEqual(PartOwners.rowSubtitle(owner: "From Sam", note: "arrives Friday"), "From Sam · arrives Friday")
        XCTAssertEqual(PartOwners.rowLabel(name: "Cake", owner: "You", step: "open"), "Cake, You, Not started")
    }

    func testSuggest_displayNames() {
        XCTAssertEqual(PartSteps.displayName(kindRaw: "gift", label: nil, title: nil), "Gift")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "gift", label: nil, title: "Blue gloves"), "Blue gloves", "Title wins for a gift")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "other", label: nil, title: "Pajamas"), "Pajamas")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "other", label: nil, title: nil), "Something else")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "gift", label: "Mug", title: "Blue gloves"), "Mug", "Label wins")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "card", label: nil, title: "A handwritten card, mailed (Rose)"), "Card",
                       "A card keeps its own name")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "dinner", label: nil, title: nil), "Dinner out")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "stocking", label: nil, title: nil), "Stocking")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "fromSanta", label: nil, title: nil), "From Santa")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "cake", label: nil, title: nil), "Cake")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "flowers", label: nil, title: nil), "Flowers")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "theDay", label: nil, title: nil), "The day")
        XCTAssertEqual(PartSteps.displayName(kindRaw: "kidsMade", label: nil, title: nil), "Gift from the kids")
    }

    // MARK: Owners (2.2)

    func testOwners_displayWords() {
        XCTAssertEqual(PartOwners.text(names: []), "You")
        XCTAssertEqual(PartOwners.text(names: ["Sam"]), "From Sam")
        XCTAssertEqual(PartOwners.text(names: ["Lily", "Rose"]), "From Lily and Rose")
        XCTAssertEqual(PartOwners.text(names: ["Lily", "Rose", "Sam"]), "From Lily, Rose and Sam")
        XCTAssertEqual(PartOwners.text(names: ["A", "B", "C", "D"]), "From A, B, C and D")
    }

    func testOwners_youIsExclusiveAndOthersCombine() {
        let lily = UUID(), rose = UUID()
        var ids = PartOwners.toggled([], tapping: lily)
        XCTAssertEqual(ids, [lily])
        ids = PartOwners.toggled(ids, tapping: rose)
        XCTAssertEqual(ids, [lily, rose])
        ids = PartOwners.toggled(ids, tapping: lily)
        XCTAssertEqual(ids, [rose])
        ids = PartOwners.toggled(ids, tapping: rose)
        XCTAssertEqual(ids, [], "Empty means You")
        XCTAssertEqual(PartOwners.you(), [], "Tapping You clears the others")
    }

    func testOwners_aRemovedPersonLeavesNoBlank() {
        let lily = UUID(), rose = UUID(), gone = UUID()
        XCTAssertEqual(PartOwners.existing([gone, rose, lily], among: [lily, rose]), [lily, rose])
        XCTAssertEqual(PartOwners.existing([gone], among: [lily, rose]), [], "Reads as You")
    }

    // MARK: Steps (2.3)

    func testSteps_newKindsJoinTheirFamily() {
        XCTAssertEqual(PartSteps.family(forKindRaw: "stocking"), .buy)
        XCTAssertEqual(PartSteps.family(forKindRaw: "fromSanta"), .buy)
        XCTAssertEqual(PartSteps.family(forKindRaw: "cake"), .orderAhead)
        XCTAssertEqual(PartSteps.family(forKindRaw: "flowers"), .orderAhead)
        XCTAssertEqual(PartSteps.family(forKindRaw: "theDay"), .day)
        XCTAssertEqual(PartSteps.family(forKindRaw: "kidsMade"), .make)
    }

    func testSteps_wordsForEveryStep() {
        let expected: [String: String] = [
            "open": "Not started", "idea": "Have an idea", "bought": "Bought", "wrapped": "Wrapped",
            "written": "Written", "making": "Making it", "finished": "Finished", "booked": "Booked",
            "ordered": "Ordered", "ready": "Ready", "done": "Done", "scheduled": "Scheduled", "arrived": "Arrived",
        ]
        for (step, word) in expected { XCTAssertEqual(PartSteps.word(for: step), word, step) }
        for family in PartSteps.Family.allCases {
            for step in PartSteps.steps(for: family) { XCTAssertNotNil(expected[step], "\(step) has a word") }
        }
        XCTAssertEqual(PartSteps.pillWord(for: "ordered"), "Ordered")
        XCTAssertEqual(PartSteps.pillWord(for: "idea"), "Have an idea")
    }

    func testSteps_readyAtTheKindsLastStep() {
        let ready: [(ActKind, String)] = [(.stocking, "wrapped"), (.fromSanta, "wrapped"), (.cake, "ready"),
                                          (.flowers, "ready"), (.theDay, "booked"), (.kidsMade, "finished")]
        for (kind, step) in ready {
            XCTAssertTrue(PartSteps.isReady(step: step, family: PartSteps.family(forKindRaw: kind.rawValue)), "\(kind)")
        }
        XCTAssertFalse(PartSteps.isReady(step: "ordered", family: .orderAhead), "Ordered is not ready")
        XCTAssertFalse(PartSteps.isReady(step: "making", family: .make))
    }

    func testSteps_suggestionKindMapping() throws {
        let w = makeWorld()
        let list = PartSuggestions.suggestions(for: .birthday, relationship: "wife")
        for s in list {
            let act = PlanStore.addPart(to: w.moment, kind: s.kind, label: s.label, in: w.context)
            XCTAssertEqual(act.kind, s.kind)
            XCTAssertEqual(PartSteps.displayName(kindRaw: act.kindRaw, label: act.label, title: act.title), s.title)
        }
    }

    func testSteps_choosingAStepStoresItAtOnce() throws {
        let w = makeWorld()
        let act = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        PlanStore.setStep(act, to: "bought")
        XCTAssertEqual(act.step, "bought")
        XCTAssertEqual(act.currentStep, "bought")
        PlanStore.setStep(act, to: "scheduled")
        XCTAssertEqual(act.step, "scheduled", "Any status from the full list can be chosen")
        PlanStore.setStep(act, to: "nonsense")
        XCTAssertEqual(act.step, "scheduled", "An unknown status is ignored")
    }

    // MARK: Nudge (2.4)

    private func part(_ name: String, _ family: PartSteps.Family, _ step: String = "open", typed: Bool = false) -> PlanNudge.Part {
        PlanNudge.Part(name: name, typed: typed, family: family, step: step)
    }

    func testNudge_leadTimes() {
        XCTAssertEqual(PlanNudge.leadDays(for: .orderAhead), 7)
        XCTAssertEqual(PlanNudge.leadDays(for: .buy), 14)
        XCTAssertEqual(PlanNudge.leadDays(for: .card), OccasionDates.cutoffDays)
        XCTAssertEqual(PlanNudge.leadDays(for: .card), 5)
        XCTAssertEqual(PlanNudge.leadDays(for: .make), 7)
        XCTAssertEqual(PlanNudge.leadDays(for: .day), 7)
        XCTAssertEqual(PlanNudge.leadDays(for: .other), 7)
        XCTAssertNil(PlanNudge.leadDays(for: .callOrMessage))
    }

    func testNudge_bothSidesOfEachLeadTime() {
        let cases: [(PartSteps.Family, String, Int, String)] = [
            (.orderAhead, "Cake", 7, "ordering"), (.buy, "Gift", 14, "buying"), (.card, "Card", 5, "mailing"),
            (.make, "Gift from the kids", 7, "planning"), (.day, "The day", 7, "planning"),
            (.other, "Pajamas", 7, "planning"),
        ]
        for (family, name, lead, word) in cases {
            let inside = PlanNudge.make(parts: [part(name, family)], daysLeft: lead)
            XCTAssertEqual(inside.note, "\(name) needs \(word) this week.", "\(name) at \(lead) days")
            let outside = PlanNudge.make(parts: [part(name, family)], daysLeft: lead + 1)
            XCTAssertEqual(outside.note?.hasPrefix("\(name) isn't started yet. "), true, "\(name) at \(lead + 1) days")
            XCTAssertEqual(outside.note?.hasSuffix(" so there's time."), true)
        }
        let call = PlanNudge.make(parts: [part("Call", .callOrMessage)], daysLeft: 1)
        XCTAssertEqual(call.note, "Call isn't started yet. It usually takes about a week, so there's time.",
                       "A call has no lead time, so it is never this week")
    }

    func testNudge_usualLines() {
        func note(_ family: PartSteps.Family, _ name: String) -> String? {
            PlanNudge.make(parts: [part(name, family)], daysLeft: 60).note
        }
        XCTAssertEqual(note(.orderAhead, "Cake"), "Cake isn't started yet. Usually ordered about a week ahead, so there's time.")
        XCTAssertEqual(note(.orderAhead, "Flowers"), "Flowers isn't started yet. Usually ordered about a week ahead, so there's time.")
        XCTAssertEqual(note(.buy, "Gift"), "Gift isn't started yet. Gifts usually take a week or two to arrive, so there's time.")
        XCTAssertEqual(note(.card, "Card"), "Card isn't started yet. Cards go in the mail about five days ahead, so there's time.")
        XCTAssertEqual(note(.day, "The day"), "The day isn't started yet. It usually takes about a week, so there's time.")
        XCTAssertEqual(note(.make, "Gift from the kids"),
                       "Gift from the kids isn't started yet. It usually takes about a week, so there's time.")
    }

    func testNudge_severalNotStarted() {
        let two = PlanNudge.make(parts: [part("Gift", .buy), part("Card", .card)], daysLeft: 60)
        XCTAssertEqual(two.note, "Gift and card aren't started yet. Gifts usually take a week or two to arrive, so there's time.")
        let three = PlanNudge.make(parts: [part("Gift", .buy), part("Card", .card), part("Cake", .orderAhead)], daysLeft: 60)
        XCTAssertEqual(three.note, "Gift, card and 1 more aren't started yet. Gifts usually take a week or two to arrive, so there's time.")
        let four = PlanNudge.make(parts: [part("Gift", .buy), part("Card", .card), part("Cake", .orderAhead),
                                          part("Flowers", .orderAhead)], daysLeft: 60)
        XCTAssertEqual(four.note, "Gift, card and 2 more aren't started yet. Gifts usually take a week or two to arrive, so there's time.")
    }

    func testNudge_startedPartsAreNotCountedAndTheButtonOpensTheLeastSlackPart() {
        // Gift is started. Card (lead 5) has slack 55 at 60 days, cake (lead 7) has 53, so the cake comes first.
        let parts = [part("Gift", .buy, "bought"), part("Card", .card), part("Cake", .orderAhead)]
        let r = PlanNudge.make(parts: parts, daysLeft: 60)
        XCTAssertEqual(r.target, 2)
        XCTAssertEqual(r.buttonTitle, "Plan the cake")
        XCTAssertEqual(r.note, "Cake and card aren't started yet. Usually ordered about a week ahead, so there's time.")
        XCTAssertTrue(r.isEnabled)
    }

    func testNudge_typedNamesKeepTheirCapitals() {
        let r = PlanNudge.make(parts: [part("Sam's mug", .buy, typed: true)], daysLeft: 60)
        XCTAssertEqual(r.buttonTitle, "Plan next: Sam's mug")
        XCTAssertEqual(PlanNudge.make(parts: [part("Cake", .orderAhead)], daysLeft: 60).buttonTitle, "Plan the cake")
    }

    func testNudge_nothingOpen() {
        let r = PlanNudge.make(parts: [part("Gift", .buy, "wrapped"), part("Card", .card, "idea")], daysLeft: 3)
        XCTAssertNil(r.note)
        XCTAssertEqual(r.buttonTitle, "Everything is planned")
        XCTAssertNil(r.target)
        XCTAssertFalse(r.isEnabled)
        XCTAssertEqual(PlanNudge.make(parts: [], daysLeft: 3).buttonTitle, "Everything is planned")
    }

    func testNudge_leastSlackComesFirst() {
        // At 10 days: cake slack 3 (lead 7), gift slack -4 (lead 14). The gift is listed second.
        let r = PlanNudge.make(parts: [part("Cake", .orderAhead), part("Gift", .buy)], daysLeft: 10)
        XCTAssertEqual(r.target, 1)
        XCTAssertEqual(r.buttonTitle, "Plan the gift")
        XCTAssertEqual(r.note, "Gift needs buying this week.")
        let outside = PlanNudge.make(parts: [part("Cake", .orderAhead), part("Gift", .buy), part("Card", .card)], daysLeft: 40)
        XCTAssertEqual(outside.target, 1, "Gift has slack 26, cake 33, card 35")
        XCTAssertEqual(outside.note, "Gift, cake and 1 more aren't started yet. Gifts usually take a week or two to arrive, so there's time.",
                       "The others follow in plan order")
    }

    func testNudge_equalSlackKeepsPlanOrderAndNoLeadTimeIsLast() {
        let r = PlanNudge.make(parts: [part("Cake", .orderAhead), part("Flowers", .orderAhead)], daysLeft: 30)
        XCTAssertEqual(r.target, 0)
        XCTAssertEqual(r.note, "Cake and flowers aren't started yet. Usually ordered about a week ahead, so there's time.")
        let call = PlanNudge.make(parts: [part("Call", .callOrMessage), part("The day", .day)], daysLeft: 30)
        XCTAssertEqual(call.target, 1, "A call has infinite slack")
    }

    func testNudge_planRowTitleForEveryOccasion() {
        let expected: [OccasionType: String] = [
            .birthday: "Plan the birthday", .anniversary: "Plan the anniversary", .christmas: "Plan Christmas",
            .valentines: "Plan Valentine's Day", .mothersDay: "Plan Mother's Day", .fathersDay: "Plan Father's Day",
            .newBaby: "Plan the new baby", .graduation: "Plan the graduation", .newHome: "Plan the new home",
            .retirement: "Plan the retirement", .event: "Plan the day", .wedding: "Plan the wedding", .custom: "Plan the day",
        ]
        for type in OccasionType.allCases { XCTAssertEqual(PlanReadiness.planRowTitle(for: type), expected[type], "\(type)") }
    }

    // MARK: A (new kinds in the older switches)

    private func planState(_ kind: ActKind, title: String? = nil, due: Date? = nil, status: MomentStatus = .planning,
                           ready: Int = 0, total: Int = 0, isPlan: Bool = false) -> MomentState {
        MomentState(id: UUID(), personName: "Anna", ring: .inner, dueDate: due ?? day(2026, 12, 20), status: status,
                    planKind: kind, planTitle: title, planDone: false, greetingDone: false, anyActDone: false,
                    openWishCount: 0, hasPhone: true, turning: nil, headsUpAt: nil,
                    partsReady: ready, partsTotal: total, isPlanMoment: isPlan)
    }

    func testA_nextActForNewKindsOnASinglePlan() {
        let now = day(2026, 11, 20, 10)
        let cutoff = OccasionDates.adding(days: -OccasionDates.cutoffDays, to: day(2026, 12, 20), calendar: cal)
        for kind in [ActKind.stocking, .fromSanta, .cake, .flowers] {
            XCTAssertEqual(NextAct.make(planState(kind), now: now, calendar: cal), .orderBy(cutoff), "\(kind)")
        }
        XCTAssertEqual(NextAct.make(planState(.theDay, title: "Breakfast in bed"), now: now, calendar: cal),
                       .finishOther("Breakfast in bed"))
        XCTAssertEqual(NextAct.make(planState(.theDay), now: now, calendar: cal), .finishOther("The day"))
        XCTAssertEqual(NextAct.make(planState(.kidsMade, title: "Painted frame"), now: now, calendar: cal),
                       .finishOther("Painted frame"))
        XCTAssertEqual(NextAct.make(planState(.kidsMade), now: now, calendar: cal), .finishOther("Gift from the kids"))
    }

    private func doneMoment(_ kind: ActKind, label: String? = nil, title: String? = nil) -> Moment {
        let w = makeWorld()
        let act = Act(role: .plan, kind: kind, title: title)
        act.label = label
        w.context.insert(act)
        act.moment = w.moment
        act.complete(.user)
        return w.moment
    }

    func testA_whatWasDoneForNewKindsOnASinglePlan() {
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.stocking)), "A stocking")
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.fromSanta)), "A gift from Santa")
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.cake)), "A cake")
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.flowers)), "Flowers")
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.theDay)), "The day")
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.theDay, label: "Breakfast in bed")), "Breakfast in bed")
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.kidsMade)), "Gift from the kids")
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.kidsMade, label: "Painted frame")), "Painted frame")
        XCTAssertEqual(MomentEngine.whatWasDone(doneMoment(.gift, title: "Blue gloves")), "Blue gloves", "Older kinds are unchanged")
    }

    // MARK: B (the older flow only replaces what it made)

    func testB_theOlderFlowReplacesItsOwnUnfinishedPlan() {
        let w = makeWorld()
        let old = Act(role: .plan, kind: .gift, title: "Blue gloves")
        w.context.insert(old)
        old.moment = w.moment
        XCTAssertTrue(PlanStore.isOldFlowPlan(old))
        XCTAssertEqual(PlanStore.removeOldFlowPlans(of: w.moment, in: w.context), 1)
        XCTAssertEqual(savedActIDs(w), [], "The unfinished plan the older flow made is gone")
    }

    func testB_aPartMadeOnThePlanScreenSurvivesChoosePlanAndMailedCard() {
        let w = makeWorld()
        let screenPart = PlanStore.addPart(to: w.moment, kind: .cake, label: nil, in: w.context)
        let oldFlow = Act(role: .plan, kind: .card)
        w.context.insert(oldFlow)
        oldFlow.moment = w.moment
        XCTAssertEqual(PlanStore.removeOldFlowPlans(of: w.moment, in: w.context), 1)
        XCTAssertEqual(savedActIDs(w), [screenPart.id], "Only the older flow's plan went")
        XCTAssertEqual(screenPart.step, "open", "A part has a stored step from the moment it's added")
    }

    func testB_anythingTheScreenStoresProtectsAPart() {
        let w = makeWorld()
        let labelled = Act(role: .plan, kind: .gift); labelled.label = "Mug"
        let noted = Act(role: .plan, kind: .gift); noted.note = "arrives Friday"
        let owned = Act(role: .plan, kind: .gift); owned.ownerIDs = [UUID()]
        let stepped = Act(role: .plan, kind: .gift); stepped.step = "idea"
        let finished = Act(role: .plan, kind: .gift); finished.complete(.user)
        for a in [labelled, noted, owned, stepped, finished] { w.context.insert(a); a.moment = w.moment }
        XCTAssertEqual(PlanStore.removeOldFlowPlans(of: w.moment, in: w.context), 0)
        XCTAssertEqual(savedActIDs(w).count, 5)
    }

    func testB_greetingsAreNeverTouched() {
        let w = makeWorld()
        let g = Act(role: .greeting, kind: .message)
        w.context.insert(g)
        g.moment = w.moment
        XCTAssertFalse(PlanStore.isOldFlowPlan(g))
        XCTAssertEqual(PlanStore.removeOldFlowPlans(of: w.moment, in: w.context), 0)
    }

    // MARK: C (setStep, completion, wishes, status)

    func testC_readyStepCompletesAndLeavingItUndoes() {
        let w = makeWorld()
        let act = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        PlanStore.setStep(act, to: "wrapped")
        XCTAssertNotNil(act.completedAt)
        XCTAssertEqual(act.confirmedRaw, ConfirmedBy.user.rawValue)
        XCTAssertTrue(act.isReady)
        PlanStore.setStep(act, to: "bought")
        XCTAssertNil(act.completedAt)
        XCTAssertNil(act.confirmedRaw)
        XCTAssertFalse(act.isReady)
        XCTAssertEqual(act.currentStep, "bought", "Stored step and completed date agree")
    }

    func testC_anAlreadyCompletedDateIsKeptWhenReadyIsPickedAgain() {
        let w = makeWorld()
        let act = PlanStore.addPart(to: w.moment, kind: .cake, label: nil, in: w.context)
        let first = day(2026, 11, 1)
        PlanStore.setStep(act, to: "ready", now: first)
        PlanStore.setStep(act, to: "ready", now: day(2026, 11, 2))
        XCTAssertEqual(act.completedAt, first)
    }

    func testC_theWishBecomesUsedAtReadyAndOpenAgainWhenLeaving() {
        let w = makeWorld()
        let wish = Wish(text: "Blue gloves")
        w.context.insert(wish)
        wish.person = w.person
        let act = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        act.wishID = wish.id
        PlanStore.setStep(act, to: "wrapped")
        XCTAssertEqual(wish.status, .used)
        PlanStore.setStep(act, to: "idea")
        XCTAssertEqual(wish.status, .open)
    }

    func testC_aWishStaysUsedWhileAnotherReadyPartUsesIt() {
        let w = makeWorld()
        let wish = Wish(text: "Blue gloves")
        w.context.insert(wish)
        wish.person = w.person
        let a = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        let b = PlanStore.addPart(to: w.moment, kind: .stocking, label: nil, in: w.context)
        a.wishID = wish.id
        b.wishID = wish.id
        PlanStore.setStep(a, to: "wrapped")
        PlanStore.setStep(b, to: "wrapped")
        PlanStore.setStep(a, to: "idea")
        XCTAssertEqual(wish.status, .used, "The stocking is still ready and uses the same wish")
        PlanStore.setStep(b, to: "idea")
        XCTAssertEqual(wish.status, .open)
    }

    func testC_aDismissedWishIsNotRevived() {
        let w = makeWorld()
        let wish = Wish(text: "Blue gloves")
        w.context.insert(wish)
        wish.person = w.person
        wish.status = .dismissed
        let act = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        act.wishID = wish.id
        PlanStore.setStep(act, to: "wrapped")
        PlanStore.setStep(act, to: "idea")
        XCTAssertEqual(wish.status, .dismissed)
    }

    func testC_statusIsPlanningUntilEveryPartIsReadyThenDone() {
        let w = makeWorld()
        let a = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        let b = PlanStore.addPart(to: w.moment, kind: .card, label: nil, in: w.context)
        XCTAssertEqual(w.moment.status, .planning, "Adding a part moves upcoming to planning")
        PlanStore.setStep(a, to: "wrapped")
        XCTAssertEqual(w.moment.status, .planning)
        PlanStore.setStep(b, to: "written")
        XCTAssertEqual(w.moment.status, .done)
        PlanStore.setStep(a, to: "bought")
        XCTAssertEqual(w.moment.status, .planning)
        let c = PlanStore.addPart(to: w.moment, kind: .cake, label: nil, in: w.context)
        PlanStore.setStep(a, to: "wrapped")
        XCTAssertEqual(w.moment.status, .planning, "A new part that is not ready keeps it planning")
        PlanStore.setStep(c, to: "ready")
        XCTAssertEqual(w.moment.status, .done)
    }

    func testC_missedLateLetGoAndClosedNeverChange() {
        for status in [MomentStatus.missed, .lateSent, .letGo, .closed] {
            let w = makeWorld(status: status)
            let a = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
            XCTAssertEqual(w.moment.status, status, "adding to \(status)")
            PlanStore.setStep(a, to: "wrapped")
            XCTAssertEqual(w.moment.status, status, "ready in \(status)")
            PlanStore.setStep(a, to: "idea")
            XCTAssertEqual(w.moment.status, status, "leaving ready in \(status)")
        }
    }

    func testC_olderSinglePlansBehaveAsBefore() {
        let w = makeWorld(status: .planning)
        let old = Act(role: .plan, kind: .gift, title: "Blue gloves")
        w.context.insert(old)
        old.moment = w.moment
        old.complete(.user)
        XCTAssertFalse(w.moment.isPlanMoment)
        PlanStore.syncStatus(w.moment)
        XCTAssertEqual(w.moment.status, .planning, "Nothing forces a status on an older single plan")
        XCTAssertNil(old.step, "Reading writes nothing")
        XCTAssertEqual(old.currentStep, "wrapped")
    }

    func testC_nothingIsWrittenUntilTheUserChangesSomething() {
        let w = makeWorld(status: .planning)
        let old = Act(role: .plan, kind: .card)
        w.context.insert(old)
        old.moment = w.moment
        _ = w.moment.planParts
        _ = w.moment.isPlanMoment
        _ = w.moment.partsReady
        XCTAssertNil(old.step)
        XCTAssertNil(old.label)
        XCTAssertNil(old.note)
        XCTAssertEqual(old.sortOrder, 0)
        XCTAssertEqual(w.moment.status, .planning)
    }

    func testC_addingAPartPutsItLastFromYouNotStarted() {
        let w = makeWorld()
        let a = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        let b = PlanStore.addPart(to: w.moment, kind: .other, label: "  Pajamas ", in: w.context)
        let c = PlanStore.addPart(to: w.moment, kind: .other, label: "   ", in: w.context)
        XCTAssertEqual(w.moment.planParts.map(\.id), [a.id, b.id, c.id])
        XCTAssertEqual([a.sortOrder, b.sortOrder, c.sortOrder], [0, 1, 2])
        XCTAssertEqual(b.label, "Pajamas")
        XCTAssertNil(c.label)
        XCTAssertEqual(b.currentStep, "open")
        XCTAssertEqual(b.ownerIDs, [])
    }

    func testC_ownersAndNotesAreStored() {
        let w = makeWorld()
        let a = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        let sam = UUID()
        PlanStore.setOwners(a, to: [sam])
        PlanStore.setNote(a, to: " arrives Friday ")
        XCTAssertEqual(a.ownerIDs, [sam])
        XCTAssertEqual(a.note, "arrives Friday")
        PlanStore.setNote(a, to: "  ")
        XCTAssertNil(a.note)
    }

    func testC_olderFlowDoneCompletesAPlanScreenPartThroughItsSteps() {
        let w = makeWorld()
        let first = PlanStore.addPart(to: w.moment, kind: .gift, label: nil, in: w.context)
        let newest = PlanStore.addPart(to: w.moment, kind: .cake, label: nil, in: w.context)
        newest.createdAt = first.createdAt.addingTimeInterval(1)
        XCTAssertEqual(newest.step, "open")
        PlanStore.completePlan(w.moment)
        XCTAssertEqual(newest.step, "ready")
        XCTAssertNotNil(newest.completedAt)
        XCTAssertTrue(newest.isReady)
        XCTAssertFalse(first.isReady)
        XCTAssertEqual(w.moment.status, .planning, "Another part is not ready")
        PlanStore.setStep(first, to: "wrapped")
        XCTAssertEqual(w.moment.status, .done)
    }

    func testC_olderFlowDoneOnAnOlderSinglePlanIsAsBefore() {
        let w = makeWorld(status: .planning)
        let wish = Wish(text: "Blue gloves")
        w.context.insert(wish)
        wish.person = w.person
        let old = Act(role: .plan, kind: .gift, title: "Blue gloves", wishID: wish.id)
        w.context.insert(old)
        old.moment = w.moment
        PlanStore.completePlan(w.moment, how: .mailed)
        XCTAssertNotNil(old.completedAt)
        XCTAssertEqual(old.confirmedRaw, ConfirmedBy.mailed.rawValue)
        XCTAssertNil(old.step, "Nothing is stored that the user did not choose")
        XCTAssertEqual(wish.status, .used)
        XCTAssertEqual(w.moment.status, .done)
    }

    // MARK: D (Home and the yearly line)

    func testD_aPlanWithOpenPartsOffersToOpenIt() {
        let now = day(2026, 11, 20, 10)
        let s = planState(.gift, ready: 2, total: 6, isPlan: true)
        XCTAssertEqual(NextAct.make(s, now: now, calendar: cal), .openPlan(ready: 2, total: 6))
        XCTAssertEqual(NextAct.openPlan(ready: 2, total: 6).title(name: "Anna"), "Open Anna's plan")
        XCTAssertFalse(NextAct.openPlan(ready: 2, total: 6).isGentle)
    }

    func testD_aPlanWithEveryPartReadyIsAllSet() {
        let now = day(2026, 11, 20, 10)
        let s = planState(.gift, ready: 3, total: 3, isPlan: true)
        XCTAssertEqual(NextAct.make(s, now: now, calendar: cal), .allSet)
        var done = s
        done.status = .done
        done.partsReady = 2
        XCTAssertEqual(NextAct.make(done, now: now, calendar: cal), .openPlan(ready: 2, total: 3),
                       "Readiness decides, not the stored status")
    }

    func testD_missedAndTheDayComeBeforeThePlan() {
        let missed = planState(.gift, status: .missed, ready: 1, total: 3, isPlan: true)
        XCTAssertEqual(NextAct.make(missed, now: day(2026, 12, 21, 10), calendar: cal), .lateNote)
        let today = planState(.gift, ready: 1, total: 3, isPlan: true)
        XCTAssertEqual(NextAct.make(today, now: day(2026, 12, 20, 10), calendar: cal), .dayOfMessage)
    }

    func testD_olderSinglePlansKeepTheirOwnStates() {
        let now = day(2026, 11, 20, 10)
        let gift = planState(.gift)
        XCTAssertEqual(NextAct.make(gift, now: now, calendar: cal),
                       .orderBy(OccasionDates.adding(days: -5, to: day(2026, 12, 20), calendar: cal)))
        var done = planState(.gift)
        done.planDone = true
        XCTAssertEqual(NextAct.make(done, now: now, calendar: cal), .allSet)
    }

    private func planMoment(_ readyParts: [(ActKind, String?)], extraOpen: [ActKind] = []) -> World {
        let w = makeWorld()
        for (kind, label) in readyParts {
            let act = PlanStore.addPart(to: w.moment, kind: kind, label: label, in: w.context)
            let family = PartSteps.family(forKindRaw: kind.rawValue)
            PlanStore.setStep(act, to: PartSteps.readyStep(for: family))
        }
        for kind in extraOpen { PlanStore.addPart(to: w.moment, kind: kind, label: nil, in: w.context) }
        return w
    }

    func testD_yearlyLineWithOneReadyPart() {
        let w = planMoment([(.other, "Pajamas")], extraOpen: [.card, .cake])
        XCTAssertEqual(MomentEngine.whatWasDone(w.moment), "Pajamas")
    }

    func testD_yearlyLineWithThreeReadyParts() {
        let w = planMoment([(.other, "Pajamas"), (.card, nil), (.cake, nil)], extraOpen: [.flowers])
        XCTAssertEqual(MomentEngine.whatWasDone(w.moment), "Pajamas, a card and a cake")
    }

    func testD_yearlyLineWithFiveReadyParts() {
        let w = planMoment([(.other, "Pajamas"), (.card, nil), (.cake, nil), (.flowers, nil), (.gift, nil)])
        XCTAssertEqual(MomentEngine.whatWasDone(w.moment), "Pajamas, a card, a cake and 2 more")
    }

    func testD_yearlyLineWithTwoAndInSortOrder() {
        XCTAssertEqual(PlanReadiness.doneList([("A card", false), ("Pajamas", true)]), "A card and Pajamas")
        let w = planMoment([(.card, nil), (.stocking, nil)])
        XCTAssertEqual(MomentEngine.whatWasDone(w.moment), "A card and a stocking")
    }

    func testD_aGreetingStillJoinsThePlanLine() {
        let w = planMoment([(.other, "Pajamas"), (.card, nil)])
        let g = Act(role: .greeting, kind: .message)
        w.context.insert(g)
        g.moment = w.moment
        g.complete(.messageSent)
        XCTAssertEqual(MomentEngine.whatWasDone(w.moment), "Pajamas and a card, and a message")
    }

    func testD_stateCarriesReadinessOnlyForPlanMoments() {
        let w = planMoment([(.gift, nil)], extraOpen: [.card])
        XCTAssertTrue(w.moment.isPlanMoment)
        XCTAssertEqual(w.moment.partsReady, 1)
        XCTAssertEqual(w.moment.planParts.count, 2)
        XCTAssertEqual(PlanMoment.status(current: .planning, ready: 1, total: 2), .planning)
        XCTAssertEqual(PlanMoment.status(current: .planning, ready: 2, total: 2), .done)
        XCTAssertNil(PlanMoment.status(current: .missed, ready: 2, total: 2))
        XCTAssertFalse(PlanMoment.isPlanMoment(planParts: 1, anyStoredStep: false))
        XCTAssertTrue(PlanMoment.isPlanMoment(planParts: 1, anyStoredStep: true))
        XCTAssertTrue(PlanMoment.isPlanMoment(planParts: 2, anyStoredStep: false))
    }

    // MARK: Helpers

    private struct World {
        let container: ModelContainer
        let context: ModelContext
        let person: Person
        let moment: Moment
    }

    /// Keeps containers alive for the length of a test, so a moment's context is not released under it.
    private var keep: [World] = []

    /// Saves, then reads every act back from the store.
    private func savedActIDs(_ w: World) -> [UUID] {
        try? w.context.save()
        return ((try? w.context.fetch(FetchDescriptor<Act>())) ?? []).map(\.id)
    }

    private func makeWorld(status: MomentStatus = .upcoming) -> World {
        let opened = Store.open(inMemory: true)
        let context = ModelContext(opened.container)
        let person = Person(name: "Anna", ring: .inner)
        let occasion = Occasion(type: .birthday, month: 1, day: 16)
        let moment = Moment(year: 2027, dueDate: day(2027, 1, 16))
        context.insert(person)
        context.insert(occasion)
        context.insert(moment)
        occasion.person = person
        moment.occasion = occasion
        moment.status = status
        let w = World(container: opened.container, context: context, person: person, moment: moment)
        keep.append(w)
        return w
    }
}
