import XCTest
@testable import HeldDear

final class PhotoFocusTests: XCTestCase {
    func testSetReadAndClear() {
        let d = UserDefaults(suiteName: "PhotoFocusTests")!
        d.removePersistentDomain(forName: "PhotoFocusTests")
        XCTAssertNil(PhotoFocus.box(for: "a.jpg", d))
        PhotoFocus.set(CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4), for: "a.jpg", d)
        XCTAssertEqual(PhotoFocus.box(for: "a.jpg", d), CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
        PhotoFocus.set(nil, for: "a.jpg", d)
        XCTAssertNil(PhotoFocus.box(for: "a.jpg", d))
    }

    func testTappedSpotStaysInsideThePhoto() {
        let b = PhotoFocus.box(around: CGPoint(x: 0.99, y: 0.01), imageSize: CGSize(width: 4000, height: 3000))
        XCTAssertLessThanOrEqual(b.maxX, 1.0001)
        XCTAssertGreaterThanOrEqual(b.minY, 0)
        XCTAssertEqual(b.width * 4000, 750, accuracy: 0.5)
    }
}
