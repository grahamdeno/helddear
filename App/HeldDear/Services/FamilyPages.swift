import UIKit

/// Family pages (decided Nov 12, 2026, the second network exception): a private page for one person's day.
/// Family adds notes from an invite link with no app or account; on the day the user sends the person the page.
/// Only the first name, the date, the user's name and line, an optional photo and family's notes go to the server,
/// and the server deletes it all 30 days after the day. The keys stay on this iPhone.
enum FamilyPages {
    static let baseURL = URL(string: "https://helddear-mail.vercel.app")!

    struct Created: Decodable {
        var id: String
        var ownerKey: String
        var inviteURL: String
        var giftURL: String
    }

    struct Note: Decodable, Identifiable, Hashable {
        var id: String
        var name: String
        var text: String
    }

    private struct OwnerView: Decodable { var notes: [Note] }
    private struct ErrorBody: Decodable { var error: String? }

    struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    static func create(firstName: String, occasion: OccasionType, date: Date, fromName: String,
                       message: String, photo: UIImage?) async throws -> Created {
        struct Body: Encodable {
            var firstName: String; var occasion: String; var date: String
            var fromName: String; var message: String; var photo: String?
        }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let body = Body(firstName: firstName, occasion: occasion.rawValue, date: f.string(from: date),
                        fromName: fromName, message: message, photo: photo.flatMap(jpeg)?.base64EncodedString())
        return try await send("POST", path: "api/pages", query: [:], body: body)
    }

    static func notes(id: String, ownerKey: String) async throws -> [Note] {
        let view: OwnerView = try await send("GET", path: "api/pages", query: ["id": id, "key": ownerKey], body: Optional<String>.none)
        return view.notes
    }

    static func removeNote(id: String, ownerKey: String, noteID: String) async throws {
        let _: ErrorBody = try await send("DELETE", path: "api/notes", query: ["id": id, "key": ownerKey, "note": noteID],
                                          body: Optional<String>.none)
    }

    static func delete(id: String, ownerKey: String) async throws {
        let _: ErrorBody = try await send("DELETE", path: "api/pages", query: ["id": id, "key": ownerKey], body: Optional<String>.none)
    }

    /// A JPEG under the server's 700 KB limit.
    static func jpeg(_ image: UIImage) -> Data? {
        let small = PhotoStore.downscale(image, maxSide: 1200)
        for q in [0.8, 0.65, 0.5, 0.35] as [CGFloat] {
            if let d = small.jpegData(compressionQuality: q), d.count < 650_000 { return d }
        }
        return nil
    }

    private static func send<B: Encodable, R: Decodable>(_ method: String, path: String, query: [String: String], body: B?) async throws -> R {
        var c = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { c.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var request = URLRequest(url: c.url!)
        request.httpMethod = method
        request.timeoutInterval = 25
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw Failure(message: status == 410 ? "This page has ended." : (message ?? "Something went wrong. Try again in a little while."))
        }
        return try JSONDecoder().decode(R.self, from: data)
    }
}
