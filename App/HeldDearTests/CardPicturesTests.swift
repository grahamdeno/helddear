import XCTest
@testable import HeldDear

/// M6 (Nov 24, 2026): card pictures come only from Held Dear's server.
final class CardPicturesTests: XCTestCase {
    private func card(_ cover: String) -> MailCard {
        MailCard(id: 1, name: "Gold Cross", cover: URL(string: cover)!, inside: nil, characters: 300)
    }

    func testAPathIsResolvedAgainstHeldDearsServer() {
        let url = card("/api/card-image?u=https%3A%2F%2Fd3e924qpzqov0g.cloudfront.net%2Fcardimages%2Fa.jpg").safeCover
        XCTAssertEqual(url?.host, MailedCards.baseURL.host)
        XCTAssertEqual(url?.path, "/api/card-image")
    }

    func testHandwryttensOwnAddressIsRefused() {
        XCTAssertNil(card("https://d3e924qpzqov0g.cloudfront.net/cardimages/a.jpg").safeCover)
    }

    func testHeldDearsServerIsAllowed() {
        XCTAssertNotNil(card("https://helddear-mail.vercel.app/api/card-image?u=x").safeCover)
    }
}
