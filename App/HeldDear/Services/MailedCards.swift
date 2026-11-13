import Foundation
import PassKit
import SwiftUI

// Mailed cards: the one place Held Dear talks to a server, and only when the user checks out.
// The server (helddear-mail on Vercel) holds the Handwrytten and Stripe keys; the app never has them.
// Sent for one order only: the chosen card, the message, the recipient's and the user's mailing
// addresses, and the Apple Pay payment token. Nothing else about the user's people leaves the phone.

struct MailCard: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var cover: URL
    var inside: URL?
    var characters: Int
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
    static let baseURL = URL(string: "https://helddear-mail.vercel.app")!
    static let merchantID = "merchant.com.grahamdeno.helddear"
    static let networks: [PKPaymentNetwork] = [.visa, .masterCard, .amex, .discover]

    struct Catalog: Decodable {
        var cards: [MailCard]
        var priceCents: Int
        var testMode: Bool?
    }

    struct OrderResult: Decodable {
        var orderId: Int?
        var mailing: String?
        var error: String?
    }

    struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    static var canPay: Bool { PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks) }

    static func catalog(occasion: String = "birthday") async throws -> Catalog {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/cards"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "occasion", value: occasion)]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
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
        request.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: request)
        let result = (try? JSONDecoder().decode(OrderResult.self, from: data)) ?? OrderResult(error: "Something went wrong. You weren't charged.")
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw Failure(message: result.error ?? "Something went wrong. You weren't charged.")
        }
        return result
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
