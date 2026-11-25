import XCTest
@testable import HeldDear

final class MailedOrdersTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "MailedOrdersTests")
        defaults.removePersistentDomain(forName: "MailedOrdersTests")
    }

    private func order(_ id: String, daysAgo: Int, test: Bool = false) -> MailedOrder {
        MailedOrder(id: id, orderNumber: "N\(id)", firstName: "Ada", cardName: "Flower Buds",
                    orderedOn: Date(timeIntervalSince1970: 1_800_000_000 - Double(daysAgo) * 86_400),
                    mailing: "Mailing within 3 business days", test: test)
    }

    func testEmptyByDefault() {
        XCTAssertEqual(MailedOrders.all(defaults), [])
    }

    func testNewestFirst() {
        MailedOrders.add(order("a", daysAgo: 5), defaults)
        MailedOrders.add(order("b", daysAgo: 1), defaults)
        MailedOrders.add(order("c", daysAgo: 9), defaults)
        XCTAssertEqual(MailedOrders.all(defaults).map(\.id), ["b", "a", "c"])
    }

    func testSameReferenceKeepsOneRow() {
        MailedOrders.add(order("a", daysAgo: 2), defaults)
        var again = order("a", daysAgo: 2)
        again.orderNumber = "N2"
        MailedOrders.add(again, defaults)
        XCTAssertEqual(MailedOrders.all(defaults).count, 1)
        XCTAssertEqual(MailedOrders.all(defaults).first?.orderNumber, "N2")
    }

    func testRemoveTestsKeepsRealOrders() {
        MailedOrders.add(order("real", daysAgo: 1), defaults)
        MailedOrders.add(order("test", daysAgo: 0, test: true), defaults)
        MailedOrders.removeTests(defaults)
        XCTAssertEqual(MailedOrders.all(defaults).map(\.id), ["real"])
    }

    func testZoomNeverMovesPastTheEdges() {
        let size = CGSize(width: 400, height: 800)
        XCTAssertEqual(ZoomMath.clamp(CGSize(width: 900, height: -900), scale: 2, in: size), CGSize(width: 200, height: -400))
        XCTAssertEqual(ZoomMath.clamp(CGSize(width: 50, height: 50), scale: 1, in: size), .zero)
        XCTAssertEqual(ZoomMath.clamp(CGSize(width: 10, height: -20), scale: 3, in: size), CGSize(width: 10, height: -20))
    }
}
