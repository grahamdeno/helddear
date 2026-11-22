import XCTest
@testable import HeldDear

/// The order on an item page (Nov 22, 2026): which items, the row names, the next step and its button, links.
final class OrdersTests: XCTestCase {
    func testOrderedAndBoughtThingsOnly() {
        XCTAssertTrue(Orders.applies(.orderAhead))
        XCTAssertTrue(Orders.applies(.buy))
        XCTAssertTrue(Orders.applies(.other))
        XCTAssertFalse(Orders.applies(.card))
        XCTAssertFalse(Orders.applies(.day))
    }

    func testTheLinkKeepsItsMeaning() {
        XCTAssertEqual(Orders.fromLabel(step: "open"), "Found at")
        XCTAssertEqual(Orders.fromLabel(step: "idea"), "Found at")
        XCTAssertEqual(Orders.fromLabel(step: "ordered"), "Ordered from")
        XCTAssertEqual(Orders.fromLabel(step: "bought"), "Bought from")
        XCTAssertEqual(Orders.arrivesLabel(step: "idea"), "Needed by")
        XCTAssertEqual(Orders.arrivesLabel(step: "ordered"), "Arrives")
        XCTAssertFalse(Orders.isPlaced("idea"))
        XCTAssertTrue(Orders.isPlaced("ordered"))
    }

    func testNextStepAndItsButton() {
        XCTAssertEqual(Orders.next(after: "open", family: .orderAhead), "idea")
        XCTAssertEqual(Orders.next(after: "idea", family: .orderAhead), "ordered")
        XCTAssertEqual(Orders.next(after: "ordered", family: .orderAhead), "ready")
        XCTAssertNil(Orders.next(after: "ready", family: .orderAhead))
        XCTAssertNil(Orders.next(after: "arrived", family: .orderAhead), "a status off the line has no next")
        XCTAssertEqual(Orders.buttonTitle(for: "ordered"), "I ordered it")
        XCTAssertEqual(Orders.buttonTitle(for: "bought"), "I bought it")
        XCTAssertEqual(Orders.buttonTitle(for: "ready"), "It's ready")
    }

    func testLinks() {
        XCTAssertEqual(Orders.link(from: "www.bakemeawish.com")?.absoluteString, "https://www.bakemeawish.com")
        XCTAssertEqual(Orders.link(from: " https://ups.com/track?n=1 ")?.absoluteString, "https://ups.com/track?n=1")
        XCTAssertNil(Orders.link(from: "chocolate cake"))
        XCTAssertNil(Orders.link(from: ""))
        XCTAssertNil(Orders.link(from: "nodot"))
        XCTAssertEqual(Orders.shortLink(URL(string: "https://www.bakemeawish.com/cakes/1")!), "bakemeawish.com")
    }
}
