import XCTest
@testable import HeldDear

final class OccasionPhotosTests: XCTestCase {
    func testOnePhotoPerOccasionSetAndCleared() {
        let d = UserDefaults(suiteName: "OccasionPhotosTests")!
        d.removePersistentDomain(forName: "OccasionPhotosTests")
        let a = UUID(), b = UUID()
        XCTAssertNil(OccasionPhotos.file(for: a, d))
        OccasionPhotos.set("x.jpg", for: a, d)
        OccasionPhotos.set("y.jpg", for: b, d)
        XCTAssertEqual(OccasionPhotos.file(for: a, d), "x.jpg")
        XCTAssertEqual(OccasionPhotos.file(for: b, d), "y.jpg")
        OccasionPhotos.set(nil, for: a, d)
        XCTAssertNil(OccasionPhotos.file(for: a, d))
        XCTAssertEqual(OccasionPhotos.file(for: b, d), "y.jpg")
    }
}
