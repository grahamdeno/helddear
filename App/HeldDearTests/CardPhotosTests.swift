import XCTest
@testable import HeldDear

/// Choosing and placing a card's photo (Nov 22, 2026): the row's order and the drag, shared by both cards.
final class CardPhotosTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func testRowOpensOnTheTopPhotoThenThisYear() {
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 22))!
        let files = ["a_d20200101.jpg", "b_d20260601.jpg", "c.jpg", "d_d20251201.jpg", "e_d20240101.jpg", "top_d20190101.jpg", "f.jpg"]
        let order = CardPhotos.order(files: files, top: "top_d20190101.jpg", now: now, calendar: cal)
        XCTAssertEqual(order, ["top_d20190101.jpg", "b_d20260601.jpg", "d_d20251201.jpg", "e_d20240101.jpg", "a_d20200101.jpg",
                               "f.jpg", "c.jpg"])
        XCTAssertEqual(CardPhotos.order(files: [], top: nil), [])
    }

    func testDragMovesTheCropAndStaysInsideThePhoto() {
        let start = CGRect(x: 100, y: 100, width: 390, height: 290)
        let size = CGSize(width: 800, height: 600)
        // Dragging right by 10 points at full scale moves the crop left by 10 pixels.
        XCTAssertEqual(CardPhotos.slide(start, imageSize: size, by: CGSize(width: 10, height: 0), scale: 1).origin.x, 90)
        // At half scale the same drag moves twice as far.
        XCTAssertEqual(CardPhotos.slide(start, imageSize: size, by: CGSize(width: 10, height: 0), scale: 0.5).origin.x, 80)
        // Never past an edge.
        let far = CardPhotos.slide(start, imageSize: size, by: CGSize(width: -5000, height: 5000), scale: 1)
        XCTAssertEqual(far.origin.x, 800 - 390)
        XCTAssertEqual(far.origin.y, 0)
    }

    func testSameHintOnBothCards() {
        XCTAssertEqual(CardPhotos.placeHint(photoCount: 1), "Drag the photo to place it.")
        XCTAssertEqual(CardPhotos.placeHint(photoCount: 3), "Drag a photo to place it. Pick another above.")
    }
}
