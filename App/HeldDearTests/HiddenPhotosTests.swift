import XCTest
@testable import HeldDear

/// Hiding a photo from Held Dear is kept on this iPhone and can be undone (feedback on build 1014).
final class HiddenPhotosTests: XCTestCase {
    func testHideAndShowAll() {
        let d = UserDefaults(suiteName: "HiddenPhotosTests-\(UUID().uuidString)")!
        XCTAssertTrue(HiddenPhotos.all(d).isEmpty)
        HiddenPhotos.hide("a", d)
        HiddenPhotos.hide("b", d)
        HiddenPhotos.hide("a", d)
        XCTAssertEqual(HiddenPhotos.all(d), ["a", "b"])
        HiddenPhotos.showAll(d)
        XCTAssertTrue(HiddenPhotos.all(d).isEmpty)
    }

    func testFilterDropsEmptyYears() {
        XCTAssertTrue(HiddenPhotos.filter([], hidden: ["a"]).isEmpty)
    }
}
