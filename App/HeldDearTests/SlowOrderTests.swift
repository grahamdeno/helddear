import XCTest
@testable import HeldDear

/// M1 (Nov 24, 2026) and Fable N1 (Nov 25, 2026): an order whose reply never came keeps its reference, checks the
/// server for about 90 seconds, and never says "not charged" or starts over on "none".
final class SlowOrderTests: XCTestCase {
    func testPlacedCountsAsDone() throws {
        let r = try XCTUnwrap(MailedCards.settled(.charged(orderId: "777"))).get()
        XCTAssertEqual(r.orderId, "777")
        let t = try XCTUnwrap(MailedCards.settled(.charged(orderId: "test-ABC"))).get()
        XCTAssertEqual(t.orderId, "test-ABC", "Test order numbers aren't numbers")
    }

    func testNoneAndPendingKeepChecking() {
        XCTAssertNil(MailedCards.settled(.none), "A lost reply never starts a new reference on none")
        XCTAssertNil(MailedCards.settled(.pending))
        XCTAssertNil(MailedCards.settled(.charged(orderId: nil)))
        XCTAssertNil(MailedCards.settled(.unknown))
    }

    func testRefundedStartsOverAndAttentionDoesNot() throws {
        guard case .failure(let r)? = MailedCards.settled(.refunded) else { return XCTFail() }
        XCTAssertTrue(r.startOver)
        guard case .failure(let a)? = MailedCards.settled(.attention) else { return XCTFail() }
        XCTAssertFalse(a.startOver)
        XCTAssertTrue(a.message.contains("support@tangomike.app"))
        XCTAssertFalse(a.message.contains("refunded"))
    }

    func testSettleWaitsForThePlacedOrder() async throws {
        var answers: [MailedCards.Standing] = [.none, .pending, .charged(orderId: nil), .charged(orderId: "42")]
        var asked = 0
        let r = await MailedCards.settle(reference: "ref-12345678", every: .zero) { _ in
            asked += 1
            return answers.removeFirst()
        }
        XCTAssertEqual(try r.get().orderId, "42")
        XCTAssertEqual(asked, 4)
    }

    func testSettleGivesUpAfterItsTriesWithoutStartingOver() async {
        var asked = 0
        let r = await MailedCards.settle(reference: "ref-12345678", tries: 9, every: .zero) { _ in asked += 1; return .none }
        XCTAssertEqual(asked, 9)
        guard case .failure(let f) = r else { return XCTFail() }
        XCTAssertFalse(f.startOver)
        XCTAssertTrue(f.message.contains("support@tangomike.app"))
        XCTAssertTrue(f.message.contains("ref-1234"))
        XCTAssertFalse(f.message.contains("weren't charged"))
    }
}
