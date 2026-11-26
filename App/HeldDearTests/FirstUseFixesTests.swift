import XCTest
@testable import HeldDear

/// First-use audit fixes (Fable, Nov 25, 2026).
final class FirstUseFixesTests: XCTestCase {
    func testU4LimitLineNamesThePlannedPeople() {
        XCTAssertEqual(PlanLimit.limitLine(names: ["Cora", "Ada", "Ben"]),
                       "Plans for three people are free. Yours are Ada, Ben and Cora. Lifetime adds plans for everyone.")
        XCTAssertEqual(PlanLimit.limitLine(names: ["Ada"]),
                       "Plans for three people are free. Yours is Ada. Lifetime adds plans for everyone.")
        XCTAssertNil(PlanLimit.limitLine(names: []))
        XCTAssertNil(PlanLimit.limitLine(names: [""]))
    }

    func testU7NewPlansStartWithThreeParts() {
        XCTAssertEqual(PartSuggestions.starter(for: .birthday, relationship: nil).map(\.title), ["Gift", "Card", "Cake"])
        XCTAssertEqual(PartSuggestions.starter(for: .birthday, relationship: "Wife").map(\.title), ["Gift", "Card", "Cake"])
        // V4: holidays start with the holiday's own parts, by relationship.
        XCTAssertEqual(PartSuggestions.starter(for: .christmas, relationship: nil).map(\.title), ["Gift", "Card"])
        XCTAssertEqual(PartSuggestions.starter(for: .christmas, relationship: "Wife").map(\.title),
                       ["Gift", "Stocking", "Card", "Gift from the kids"])
        XCTAssertEqual(PartSuggestions.starter(for: .event, relationship: nil).count, 3)
    }

    func testV1TheEmptyPlanButtonNamesThePerson() {
        XCTAssertEqual(PersonPlanSection.startTitle(name: "Ada", isBirthday: true), "Plan Ada's birthday")
        XCTAssertEqual(PersonPlanSection.startTitle(name: "Ada", isBirthday: false), "Plan Ada's day")
        XCTAssertEqual(PersonPlanSection.startTitle(name: "", isBirthday: true), "Plan the birthday")
    }

    func testV3PlanLimitTipWording() {
        XCTAssertEqual(FirstUseTip.planLimit.line, "All three free plans are now in use. Lifetime adds plans for everyone.")
    }
}
