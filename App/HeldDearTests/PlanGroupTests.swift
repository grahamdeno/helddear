import XCTest
@testable import HeldDear

/// The person page's plan, grouped by what each thing is (approved Nov 20, 2026).
final class PlanGroupTests: XCTestCase {
    func testEveryKindHasAGroup() {
        XCTAssertEqual(PlanGroup.group(forKindRaw: "gift"), .gifts)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "kidsMade"), .gifts)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "stocking"), .gifts)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "fromSanta"), .gifts)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "dinner"), .theDay)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "cake"), .theDay)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "theDay"), .theDay)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "flowers"), .touches)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "card"), .touches)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "other"), .touches)
        XCTAssertEqual(PlanGroup.group(forKindRaw: "something-new"), .touches, "Unknown kinds still land somewhere")
    }

    func testWords() {
        XCTAssertEqual(PlanGroup.allCases.map(\.title), ["Gifts", "The day", "Little touches"])
        XCTAssertEqual(PlanGroup.summary(ready: 1, total: 3), "1 of 3 ready")
        XCTAssertEqual(PlanGroup.summary(ready: 2, total: 2), "All ready")
        XCTAssertEqual(PlanGroup.countLine(toDecide: 5, onTheWay: 3, ready: 1), "5 to decide · 3 on the way · 1 ready")
        XCTAssertEqual(PlanGroup.countLine(toDecide: 0, onTheWay: 0, ready: 2), "2 ready")
    }
}
