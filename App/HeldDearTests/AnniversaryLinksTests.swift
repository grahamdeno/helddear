import XCTest
@testable import HeldDear

final class AnniversaryLinksTests: XCTestCase {
    private let mom = AnniversaryLinks.Someone(id: UUID(), name: "Mom", fullName: "Ann Lee")
    private let dad = AnniversaryLinks.Someone(id: UUID(), name: "Dad", fullName: "Ben Lee")
    private let ada = AnniversaryLinks.Someone(id: UUID(), name: "Ada", fullName: "Ada Fox")
    private var people: [AnniversaryLinks.Someone] { [mom, dad, ada] }

    private func day(_ owner: AnniversaryLinks.Someone, _ month: Int = 9, _ d: Int = 16, year: Int? = nil,
                     partner: String? = nil, planned: Int = 0) -> AnniversaryLinks.Day {
        .init(id: UUID(), ownerID: owner.id, month: month, day: d, year: year, partnerName: partner, planned: planned)
    }

    private func defaults() -> UserDefaults {
        let name = "links-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    // Shown on both pages
    func testLinkedAnniversaryShowsOnPartnersPage() {
        let a = day(mom, partner: "Dad")
        let shared = AnniversaryLinks.shared(with: dad.id, days: [a], links: [a.id: dad.id])
        XCTAssertEqual(shared, [a])
        XCTAssertTrue(AnniversaryLinks.shared(with: mom.id, days: [a], links: [a.id: dad.id]).isEmpty, "owner sees it as their own")
        XCTAssertTrue(AnniversaryLinks.shared(with: ada.id, days: [a], links: [a.id: dad.id]).isEmpty)
    }

    func testTypedNameAloneIsNotShared() {
        let a = day(mom, partner: "Dad")
        XCTAssertTrue(AnniversaryLinks.shared(with: dad.id, days: [a], links: [:]).isEmpty)
    }

    // Names stay current; removal keeps the typed name
    func testPartnerNameFollowsRenameAndFallsBackToTyped() {
        let renamed = AnniversaryLinks.Someone(id: dad.id, name: "Benny", fullName: "Ben Lee")
        XCTAssertEqual(AnniversaryLinks.partnerName(typed: "Dad", linked: renamed), "Benny")
        XCTAssertEqual(AnniversaryLinks.partnerName(typed: " Dad ", linked: nil), "Dad")
        XCTAssertNil(AnniversaryLinks.partnerName(typed: "  ", linked: nil))
    }

    // Couples you already have
    func testCombineOfferedForSameDateWhenOneNamesTheOther() {
        let a = day(mom, partner: "Dad"), b = day(dad, partner: nil)
        let offers = AnniversaryLinks.combineOffers(days: [a, b], links: [:], people: people, skipped: { _, _ in false })
        XCTAssertEqual(offers.count, 1)
    }

    func testCombineNotOfferedForDifferentDatesUnrelatedOrSkipped() {
        let a = day(mom, partner: "Dad"), b = day(dad, 9, 17)
        XCTAssertTrue(AnniversaryLinks.combineOffers(days: [a, b], links: [:], people: people, skipped: { _, _ in false }).isEmpty)
        let c = day(mom, partner: "Zed"), e = day(ada)
        XCTAssertTrue(AnniversaryLinks.combineOffers(days: [c, e], links: [:], people: people, skipped: { _, _ in false }).isEmpty)
        let f = day(mom, partner: "Dad"), g = day(dad)
        XCTAssertTrue(AnniversaryLinks.combineOffers(days: [f, g], links: [:], people: people, skipped: { _, _ in true }).isEmpty)
    }

    func testCombineKeepsTheOneWithMorePlannedThenTheYear() {
        let a = day(mom, planned: 0), b = day(dad, planned: 2)
        XCTAssertEqual(AnniversaryLinks.keeper(a, b).keep, b)
        let c = day(mom, year: 2010), e = day(dad)
        XCTAssertEqual(AnniversaryLinks.keeper(c, e).keep, c)
        XCTAssertEqual(AnniversaryLinks.keeper(e, c).keep, c)
    }

    // Picking the partner
    func testChoicesExcludeOwnerAndPutPartnersFirst() {
        let list = AnniversaryLinks.choices(for: mom.id, typed: "", people: people, partnerIDs: [dad.id])
        XCTAssertEqual(list.map(\.id), [dad.id, ada.id])
        XCTAssertEqual(AnniversaryLinks.choices(for: mom.id, typed: "fox", people: people, partnerIDs: []).map(\.id), [ada.id])
    }

    // Stored links
    func testLinksStoreAndClear() {
        let d = defaults(), o = UUID()
        AnniversaryLinks.set(dad.id, for: o, d)
        XCTAssertEqual(AnniversaryLinks.partner(of: o, d), dad.id)
        AnniversaryLinks.set(nil, for: o, d)
        XCTAssertNil(AnniversaryLinks.partner(of: o, d))
    }

    func testSkipIsOrderFree() {
        let d = defaults(), a = UUID(), b = UUID()
        AnniversaryLinks.skip(a, b, d)
        XCTAssertTrue(AnniversaryLinks.isSkipped(b, a, d))
    }

    func testLinksAreSyncedSettings() {
        XCTAssertTrue(ICloudSync.Settings.keys.contains(AnniversaryLinks.key))
        XCTAssertTrue(ICloudSync.Settings.keys.contains(AnniversaryLinks.skippedKey))
    }
}
