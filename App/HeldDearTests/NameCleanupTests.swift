import XCTest
@testable import HeldDear

final class NameCleanupTests: XCTestCase {
    func testOccasionWordsComeOff() {
        XCTAssertEqual(NameCleanup.strip("Mom anniversary"), "Mom")
        XCTAssertEqual(NameCleanup.strip("Sam's birthday"), "Sam")
        XCTAssertEqual(NameCleanup.strip("Ada bday"), "Ada")
        XCTAssertEqual(NameCleanup.strip("Birthday"), "Birthday")
        XCTAssertEqual(NameCleanup.strip("Rosa Bell"), "Rosa Bell")
    }

    func testSamePersonIgnoresCaseAndEmoji() {
        XCTAssertTrue(NameCleanup.isSamePerson("ada", name: "Ada 🎂", fullName: "Ada Lee"))
        XCTAssertTrue(NameCleanup.isSamePerson("Ada Lee", name: "Ada", fullName: "Ada Lee"))
        XCTAssertFalse(NameCleanup.isSamePerson("Bea", name: "Ada", fullName: "Ada Lee"))
        XCTAssertFalse(NameCleanup.isSamePerson("", name: "Ada", fullName: ""))
    }
}
