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
}
