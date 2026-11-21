import XCTest
@testable import HeldDear

final class PlacesTests: XCTestCase {
    // Two real ZIP code centers (Census), in degrees: Springfield, IL 62701 and Chicago, IL 60601 (about 185 miles),
    // and a nearby one, Chatham, IL 62629 (about 10 miles from 62701).
    private let centers = ZipCenters(csv: "62701,3980,-8965\n60601,4189,-8762\n62629,3968,-8971\n")

    func testKnownDistance() {
        let miles = centers.miles(from: "62701", to: "60601")!
        XCTAssertEqual(miles, 181, accuracy: 10)
    }

    func testFarPlaceIsNotOffered() {
        let far = Place(kindRaw: "cake", name: "Lakeside Bakery", zip: "60601")
        let near = Place(kindRaw: "cake", name: "Main St Cakes", zip: "62629")
        let offered = Places.offered([far, near], kindRaw: "cake", personZip: "62701", centers: centers)
        XCTAssertEqual(offered.map(\.name), ["Main St Cakes"])
    }

    func testMissingZipKeepsThePlace() {
        let noZip = Place(kindRaw: "cake", name: "Home Bakery")
        let far = Place(kindRaw: "cake", name: "Lakeside Bakery", zip: "60601")
        XCTAssertEqual(Places.offered([noZip, far], kindRaw: "cake", personZip: nil, centers: centers).count, 2)
        XCTAssertEqual(Places.offered([noZip], kindRaw: "cake", personZip: "62701", centers: centers).count, 1)
    }

    func testPlacesStayOnTheirKind() {
        let baker = Place(kindRaw: "cake", name: "Main St Cakes")
        XCTAssertTrue(Places.offered([baker], kindRaw: "flowers", personZip: nil, centers: centers).isEmpty)
        XCTAssertTrue(Places.hasWhereFrom(.cake))
        XCTAssertFalse(Places.hasWhereFrom(.gift))
    }

    func testRememberingSameNameRefreshes() {
        let a = Place(kindRaw: "cake", name: "Main St Cakes", lastUsed: Date(timeIntervalSince1970: 0))
        let b = Place(kindRaw: "cake", name: "main st  cakes", phone: "555-0100")
        let list = Places.remembering(b, in: [a])
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].phone, "555-0100")
        XCTAssertEqual(list[0].id, a.id)
    }

    func testZipFromText() {
        XCTAssertEqual(Places.zip(in: "1 Main St, Springfield, IL 62701-1234"), "62701")
        XCTAssertEqual(Places.zip(in: "62629"), "62629")
        XCTAssertNil(Places.zip(in: "no zip"))
    }

    func testStoreChoosesAndForgets() {
        let defaults = UserDefaults(suiteName: "PlacesTests")!
        defaults.removePersistentDomain(forName: "PlacesTests")
        let store = PlaceStore(defaults: defaults)
        let act = UUID()
        store.choose(Place(kindRaw: "cake", name: "Main St Cakes"), for: act)
        XCTAssertEqual(store.chosen(for: act)?.name, "Main St Cakes")
        store.forget(store.all[0])
        XCTAssertNil(store.chosen(for: act))
        XCTAssertTrue(store.all.isEmpty)
    }

    func testSavedAddressSetAndClear() {
        let defaults = UserDefaults(suiteName: "AddressTests")!
        defaults.removePersistentDomain(forName: "AddressTests")
        let store = SavedAddresses(defaults: defaults)
        let id = UUID()
        store.set(MailAddress(firstName: "Ada", address1: "1 Main St", city: "Springfield", state: "IL", zip: "62701"), for: id)
        XCTAssertEqual(store.address(for: id)?.zip, "62701")
        store.set(nil, for: id)
        XCTAssertNil(store.address(for: id))
    }
}
