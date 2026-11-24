import XCTest
@testable import HeldDear

/// Fable's audit UX-7 (Nov 24, 2026): borders and dividers at least 3:1 against the page; text at least 4.5:1.
final class ContrastTests: XCTestCase {
    private func luminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF) + 0.7152 * channel((hex >> 8) & 0xFF) + 0.0722 * channel(hex & 0xFF)
    }
    private func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    func testLinesReachThreeToOneAndTextFourAndAHalf() {
        for pair in Brand.contrastPairs {
            let need = pair.name.hasSuffix("ine") || pair.name.hasSuffix("Line") ? 3.0 : 4.5
            XCTAssertGreaterThanOrEqual(ratio(pair.light, Brand.pageHex.light), need, "\(pair.name) light")
            XCTAssertGreaterThanOrEqual(ratio(pair.dark, Brand.pageHex.dark), need, "\(pair.name) dark")
        }
    }
}

final class UndoTimingTests: XCTestCase {
    func testUndoStaysLongerAndIsAnnounced() {
        XCTAssertEqual(UndoTiming.seconds(voiceOver: false), 8)
        XCTAssertEqual(UndoTiming.seconds(voiceOver: true), 20)
        XCTAssertEqual(UndoTiming.announcement("Wish removed"), "Wish removed. Undo is available.")
    }
}
