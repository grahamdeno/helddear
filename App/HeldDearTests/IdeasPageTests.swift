import XCTest
@testable import HeldDear

final class IdeasPageTests: XCTestCase {
    func testKidsIdeasOnlyForSomeoneTheKidsWouldGiveTo() {
        XCTAssertTrue(Relationship.kidsCouldGive(relationship: "Wife", isInner: false))
        XCTAssertTrue(Relationship.kidsCouldGive(relationship: "Grandma", isInner: false))
        XCTAssertTrue(Relationship.kidsCouldGive(relationship: nil, isInner: true), "unset, inner ring: offered")
        XCTAssertFalse(Relationship.kidsCouldGive(relationship: nil, isInner: false))
        XCTAssertFalse(Relationship.kidsCouldGive(relationship: "Niece", isInner: true))
        XCTAssertFalse(Relationship.kidsCouldGive(relationship: "Daughter", isInner: true))
        XCTAssertFalse(Relationship.kidsCouldGive(relationship: "Friend", isInner: true))
    }
}
