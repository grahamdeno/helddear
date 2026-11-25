import XCTest
@testable import HeldDear

/// M1 (Nov 24, 2026): an order whose reply never came is never reported as "not charged" without asking the server.
final class SlowOrderTests: XCTestCase {
    func testPaidAndPlacedCountsAsDone() throws {
        let r = try MailedCards.slowReplyOutcome(.charged(orderId: 777)).get()
        XCTAssertEqual(r.orderId, "777")
    }

    func testPaidButNotYetPlacedNeverSaysNotCharged() {
        guard case .failure(let f) = MailedCards.slowReplyOutcome(.charged(orderId: nil)) else { return XCTFail() }
        XCTAssertTrue(f.message.contains("payment went through"))
        XCTAssertFalse(f.message.contains("weren't charged"))
        XCTAssertFalse(f.startOver, "Same reference, so a retry can't charge twice")
    }

    func testUnknownKeepsTheReference() {
        guard case .failure(let f) = MailedCards.slowReplyOutcome(.unknown) else { return XCTFail() }
        XCTAssertFalse(f.startOver)
        XCTAssertFalse(f.message.contains("weren't charged"))
    }

    func testNothingChargedOrRefundedStartsOver() {
        guard case .failure(let a) = MailedCards.slowReplyOutcome(.none), case .failure(let b) = MailedCards.slowReplyOutcome(.refunded) else { return XCTFail() }
        XCTAssertTrue(a.startOver && b.startOver)
        XCTAssertTrue(a.message.contains("weren't charged"))
    }

    func testOrderNumberReadsAsNumberOrText() throws {
        let live = try JSONDecoder().decode(MailedCards.OrderResult.self, from: Data(#"{"orderId": 777, "mailing": "Mailing within 3 business days"}"#.utf8))
        XCTAssertEqual(live.orderId, "777")
        let test = try JSONDecoder().decode(MailedCards.OrderResult.self, from: Data(#"{"orderId": "test-abc12345", "test": true}"#.utf8))
        XCTAssertEqual(test.orderId, "test-abc12345")
    }
}
