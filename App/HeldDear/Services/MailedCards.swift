import Foundation
import PassKit
import SwiftUI

// Mailed cards: Held Dear talks to its own server (helddear-mail on Vercel) only inside the mailed-card flow: to list
// the cards and their pictures when the flow opens, and to place the order at checkout. Card pictures come through the
// same server, never from Handwrytten directly (M6, Nov 24, 2026). The server holds the Handwrytten and Stripe keys; the
// app never has them. Sent for one order only: the chosen card, the message, the recipient's and the user's mailing
// addresses, and the Apple Pay payment token. Nothing else about the user's people leaves the phone.

struct MailCard: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var cover: URL
    var inside: URL?
    var characters: Int
    /// Handwrytten's short description, for search (servers before Nov 22, 2026 don't send it).
    var description: String? = nil

    /// The picture's address, only if it's on Held Dear's own server (M6). A path is resolved against the server; any
    /// other host (an older server sent Handwrytten's) gives nil, so the picker shows a plain fill instead.
    var safeCover: URL? { MailCard.onServer(cover) }
    var safeInside: URL? { inside.flatMap(MailCard.onServer) }

    static func onServer(_ url: URL) -> URL? {
        if url.host == nil { return URL(string: url.relativeString, relativeTo: MailedCards.baseURL)?.absoluteURL }
        return [MailedCards.liveURL.host, MailedCards.testURL.host].contains(url.host) ? url : nil
    }
}

struct MailAddress: Codable, Equatable {
    var firstName = ""
    var lastName = ""
    var address1 = ""
    var address2 = ""
    var city = ""
    var state = ""
    var zip = ""

    var isComplete: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty && !address1.isEmpty && !city.isEmpty
            && state.count == 2 && zip.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
    }

    var oneLine: String {
        [address1, address2, "\(city), \(state) \(zip)"].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// The user's own return address, kept on this iPhone.
    static var saved: MailAddress? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "returnAddress") else { return nil }
            return try? JSONDecoder().decode(MailAddress.self, from: data)
        }
        set {
            UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "returnAddress")
        }
    }
}

enum MailedCards {
    static let liveURL = URL(string: "https://helddear-mail.vercel.app")!
    /// The price shown before the card flow opens; the server's catalog (retailCents, default 799) sets the charge.
    /// Approved Nov 24, 2026. Change both together.
    static let displayPrice = "$7.99"
    /// The test copy of the server: Stripe test keys, nothing is ever mailed. Only TestFlight builds can choose it.
    static let testURL = URL(string: "https://helddear-mail-git-card-test-ground-truth7.vercel.app")!
    static let testServerKey = "useTestCardServer"
    static var usesTestServer: Bool { AppFeatures.testFlightTools && UserDefaults.standard.bool(forKey: testServerKey) }
    static var baseURL: URL { usesTestServer ? testURL : liveURL }
    static let merchantID = "merchant.com.grahamdeno.helddear"
    static let networks: [PKPaymentNetwork] = [.visa, .masterCard, .amex, .discover]

    struct Catalog: Decodable {
        var cards: [MailCard]
        /// Any-occasion designs beyond the occasion's own (servers before Nov 21, 2026 don't send it).
        var more: [MailCard]?
        var priceCents: Int
        var testMode: Bool?
        /// Every personal category with its cards, and the occasion's own category name, for the menu and search
        /// (Nov 22, 2026). Servers before then don't send them; the picker then shows the list as before.
        var sections: [Section]?
        var own: String?
        /// The last day to order for Christmas, "2026-12-13" (servers before Nov 24, 2026 don't send it).
        var christmasOrderBy: String?
    }

    struct Section: Decodable, Hashable {
        var name: String
        var cards: [MailCard]
    }

    struct OrderResult: Decodable {
        /// Handwrytten's order number, or "test-…" from the test server; either way shown to the person as text.
        var orderId: String?
        var mailing: String?
        var error: String?
        /// True when the server refunded this order; a new card then needs a new reference.
        var refunded: Bool?
        /// True when the payment for this reference is still being confirmed (Fable N2).
        var pending: Bool?

        init(orderId: String? = nil, mailing: String? = nil, error: String? = nil, refunded: Bool? = nil) {
            self.orderId = orderId; self.mailing = mailing; self.error = error; self.refunded = refunded
        }

        enum CodingKeys: String, CodingKey { case orderId, mailing, error, refunded, pending }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let n = try? c.decodeIfPresent(Int.self, forKey: .orderId) { orderId = String(n) }
            else { orderId = try? c.decodeIfPresent(String.self, forKey: .orderId) }
            mailing = try? c.decodeIfPresent(String.self, forKey: .mailing)
            error = try? c.decodeIfPresent(String.self, forKey: .error)
            refunded = try? c.decodeIfPresent(Bool.self, forKey: .refunded)
            pending = try? c.decodeIfPresent(Bool.self, forKey: .pending)
        }
    }

    struct Failure: LocalizedError {
        var message: String
        /// Whether the next try should use a new reference: only when nothing was charged, or it was refunded.
        var startOver = false
        var errorDescription: String? { message }
    }

    /// Where one order stands on the server, from its own record (M1; Fable N1, Nov 25, 2026).
    enum Standing: Equatable { case none, pending, charged(orderId: String?), refunded, attention, unknown }

    static let support = "support@tangomike.app"

    /// The answer for an order whose reply never came, once the server's standing settles it; nil means keep checking.
    /// "none" never starts a new reference: the first reply may still be on its way (Fable N1). Plain rules, unit tested.
    static func settled(_ standing: Standing) -> Result<OrderResult, Failure>? {
        switch standing {
        case .charged(let id?):
            return .success(OrderResult(orderId: id, mailing: "Mailing within 3 business days"))
        case .refunded:
            return .failure(Failure(message: "The card couldn't be placed, so the payment was refunded.", startOver: true))
        case .attention:
            return .failure(Failure(message: "Something went wrong after your payment. It's being handled, and you won't be charged for a card that isn't mailed. If you need help, write to \(support)."))
        case .none, .pending, .charged(nil), .unknown:
            return nil
        }
    }

    /// After about 90 seconds with no settled answer: say so plainly, keep the reference, and give the support address.
    static func notConfirmed(reference: String) -> Failure {
        Failure(message: "We couldn't confirm this order yet. You won't be charged twice for it. If you need help, write to \(support) and give reference \(reference.prefix(8)).")
    }

    /// Checks where the order stands every 10 seconds for about 90 seconds (Fable N1).
    static func settle(reference: String, tries: Int = 9, every: Duration = .seconds(10),
                       check: (String) async -> Standing = standing(reference:)) async -> Result<OrderResult, Failure> {
        for attempt in 0..<tries {
            if attempt > 0 { try? await Task.sleep(for: every) }
            if let answer = settled(await check(reference)) { return answer }
        }
        return .failure(notConfirmed(reference: reference))
    }

    static func standing(reference: String) async -> Standing {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/order-status"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "reference", value: reference)]
        struct Reply: Decodable { var state: String; var orderId: String? }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return .unknown }
        switch reply.state {
        case "none": return .none
        case "pending": return .pending
        case "refunded": return .refunded
        case "attention": return .attention
        case "charged": return .charged(orderId: reply.orderId)
        default: return .unknown
        }
    }

    static var canPay: Bool { PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks) }

    static func catalog(occasion: String = "birthday") async throws -> Catalog {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/cards"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "occasion", value: occasion)]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 503 {
            // TestFlight builds say how to reach the test server (build 1055: the switch was off).
            throw Failure(message: AppFeatures.testFlightTools && !usesTestServer
                ? "Mailed cards are paused on the live server. To try them with test payments, turn on You > TestFlight only > Test card server."
                : "Mailed cards are paused right now. Please try again later.")
        }
        guard code == 200 else {
            throw Failure(message: "Cards are unavailable right now. Try again in a little while.")
        }
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    static func placeOrder(reference: String, card: MailCard, message: String, wishes: String,
                           recipient: MailAddress, sender: MailAddress, occasion: String = "birthday",
                           payment: PKPayment) async throws -> OrderResult {
        struct ApplePay: Encodable { var paymentData: String; var transactionIdentifier: String; var network: String; var displayName: String }
        struct Body: Encodable {
            var reference: String; var cardId: Int; var message: String; var wishes: String
            var recipient: MailAddress; var sender: MailAddress; var applePay: ApplePay; var occasion: String
        }
        let method = payment.token.paymentMethod
        let body = Body(reference: reference, cardId: card.id, message: message, wishes: wishes,
                        recipient: recipient, sender: sender,
                        applePay: ApplePay(paymentData: payment.token.paymentData.base64EncodedString(),
                                           transactionIdentifier: payment.token.transactionIdentifier,
                                           network: method.network?.rawValue ?? "",
                                           displayName: method.displayName ?? ""),
                        occasion: occasion)
        var request = URLRequest(url: baseURL.appendingPathComponent("api/order"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 35
        let reply: (Data, URLResponse)
        do {
            reply = try await URLSession.shared.data(for: request)
        } catch {
            // No reply (slow network, timeout): never guess. Ask the server where this order stands (M1, N1).
            return try await settle(reference: reference).get()
        }
        let (data, response) = reply
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let result = try? JSONDecoder().decode(OrderResult.self, from: data) {
            if code == 200 { return result }
            // Still being confirmed (a charge already under way for this reference): check, never charge again (N2).
            if code == 409, result.pending == true { return try await settle(reference: reference).get() }
            // 402 and 400 mean nothing was charged; a refund means this reference is finished.
            let startOver = result.refunded == true || code == 402 || code == 400 || code == 429 || code == 503
            throw Failure(message: result.error ?? "Something went wrong.", startOver: startOver)
        }
        // A reply we can't read: ask the server rather than guess.
        return try await settle(reference: reference).get()
    }
}

/// Runs the Apple Pay sheet and places the order while the sheet is still up, so the sheet's own
/// check mark or error reflects whether the card was really placed.
@MainActor
final class ApplePayCheckout: NSObject, PKPaymentAuthorizationControllerDelegate {
    private var controller: PKPaymentAuthorizationController?
    private var onPayment: ((PKPayment) async -> Result<MailedCards.OrderResult, Error>)?
    private var finish: ((Result<MailedCards.OrderResult, Error>?) -> Void)?
    private var outcome: Result<MailedCards.OrderResult, Error>?

    func start(priceCents: Int, label: String,
               onPayment: @escaping (PKPayment) async -> Result<MailedCards.OrderResult, Error>,
               finish: @escaping (Result<MailedCards.OrderResult, Error>?) -> Void) {
        let request = PKPaymentRequest()
        request.merchantIdentifier = MailedCards.merchantID
        request.supportedNetworks = MailedCards.networks
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "US"
        request.currencyCode = "USD"
        let amount = NSDecimalNumber(value: Double(priceCents) / 100)
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: label, amount: amount),
            PKPaymentSummaryItem(label: "Held Dear", amount: amount),
        ]
        self.onPayment = onPayment
        self.finish = finish
        outcome = nil
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        self.controller = controller
        controller.present { presented in
            if !presented { finish(.failure(MailedCards.Failure(message: "Apple Pay couldn't open. Check Wallet & Apple Pay in Settings."))) }
        }
    }

    nonisolated func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                                    didAuthorizePayment payment: PKPayment,
                                                    handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        Task { @MainActor in
            let result = await self.onPayment?(payment) ?? .failure(MailedCards.Failure(message: "Something went wrong."))
            self.outcome = result
            switch result {
            case .success: completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            case .failure: completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            }
        }
    }

    nonisolated func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        Task { @MainActor in
            controller.dismiss {
                Task { @MainActor in
                    self.finish?(self.outcome)
                    self.controller = nil
                }
            }
        }
    }
}
