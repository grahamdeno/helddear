import XCTest
@testable import HeldDear

final class FaceFrameTests: XCTestCase {
    func testSquareCentersOnTheFaceAndStaysInside() {
        let size = CGSize(width: 1000, height: 800)
        let face = CGRect(x: 600, y: 200, width: 150, height: 150)
        let sq = FaceFrame.portraitSquare(face: face, imageSize: size)
        XCTAssertEqual(sq.width, 300, accuracy: 0.01)
        XCTAssertEqual(sq.width, sq.height)
        XCTAssertEqual(sq.midX, face.midX, accuracy: 0.01)
        XCTAssertTrue(CGRect(origin: .zero, size: size).contains(sq))
    }

    func testFaceNearAnEdgeIsClampedInside() {
        let size = CGSize(width: 1000, height: 800)
        let sq = FaceFrame.portraitSquare(face: CGRect(x: 950, y: 0, width: 50, height: 60), imageSize: size)
        XCTAssertTrue(CGRect(origin: .zero, size: size).contains(sq))
    }

    func testBigFaceNeverExceedsThePhoto() {
        let size = CGSize(width: 600, height: 900)
        let sq = FaceFrame.portraitSquare(face: CGRect(x: 0, y: 100, width: 600, height: 700), imageSize: size)
        XCTAssertEqual(sq.width, 600, accuracy: 0.01)
    }

    func testNoFaceGivesTheCenteredSquare() {
        let sq = FaceFrame.portraitSquare(face: nil, imageSize: CGSize(width: 1000, height: 800))
        XCTAssertEqual(sq, CGRect(x: 100, y: 0, width: 800, height: 800))
    }

    func testVisionBoxFlipsToTopLeft() {
        let r = FaceFrame.pixelRect(normalized: CGRect(x: 0.5, y: 0.6, width: 0.2, height: 0.3), imageSize: CGSize(width: 100, height: 200))
        XCTAssertEqual(r.minX, 50, accuracy: 0.01)
        XCTAssertEqual(r.minY, 20, accuracy: 0.01)
        XCTAssertEqual(r.height, 60, accuracy: 0.01)
    }

    func testLargestFaceWins() {
        let small = CGRect(x: 0, y: 0, width: 10, height: 10), big = CGRect(x: 0, y: 0, width: 30, height: 30)
        XCTAssertEqual(FaceFrame.largest([small, big]), big)
        XCTAssertNil(FaceFrame.largest([]))
    }
}
