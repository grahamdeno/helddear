import XCTest
@testable import HeldDear

/// Which days are offered when adding one (feedback on build 1011).
final class OccasionOfferTests: XCTestCase {
    func testRareDaysAreSomethingElse() {
        XCTAssertFalse(OccasionOffer.firstDate.contains(.retirement))
        XCTAssertFalse(OccasionOffer.firstDate.contains(.newHome))
        XCTAssertFalse(OccasionOffer.bigDays.contains(.retirement))
        XCTAssertEqual(OccasionOffer.firstDate.first, .birthday)
        XCTAssertEqual(OccasionOffer.firstDate.last, .event)
        XCTAssertTrue(OccasionOffer.bigDays.contains(.wedding))
    }

    func testParentsDaysFollowTheRelationship() {
        XCTAssertFalse(OccasionOffer.offersHoliday(.fathersDay, relationship: "Wife"))
        XCTAssertTrue(OccasionOffer.offersHoliday(.mothersDay, relationship: "Wife"))
        XCTAssertFalse(OccasionOffer.offersHoliday(.mothersDay, relationship: "Dad"))
        XCTAssertTrue(OccasionOffer.offersHoliday(.fathersDay, relationship: "Husband"))
        XCTAssertTrue(OccasionOffer.offersHoliday(.mothersDay, relationship: nil))
        XCTAssertTrue(OccasionOffer.offersHoliday(.fathersDay, relationship: nil))
        XCTAssertTrue(OccasionOffer.offersHoliday(.christmas, relationship: "Friend"))
    }

    func testWeddingWords() {
        XCTAssertEqual(OccasionType.wedding.kind, .once)
        XCTAssertEqual(OccasionType.wedding.subject(name: "Sam"), "Sam's wedding")
        XCTAssertEqual(OccasionType.event.subject(name: "Nora", partner: "Ballet recital"), "Nora's ballet recital")
    }
}
