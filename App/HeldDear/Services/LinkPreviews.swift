import Foundation
import LinkPresentation
import UIKit

/// A saved idea's link shows like a link preview (Graham, Nov 21, 2026): the page's title and main image.
/// The phone asks that one page for its preview, once, when the idea is saved or first shown. Nothing goes to Held
/// Dear; the title and image are kept with the idea so the page isn't asked again.
enum LinkPreviews {
    struct Preview { var title: String?; var image: UIImage? }

    /// The first web address in a piece of text, when the text is a link.
    static func link(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let match = detector.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let url = match.url, url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }

    /// Whether the text is only a link (nothing typed around it).
    static func isOnlyALink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = link(in: trimmed) else { return false }
        return trimmed.count <= url.absoluteString.count + 2 || !trimmed.contains(" ")
    }

    /// "amazon.com" from a long shop link: what to show when there's no title yet.
    static func shortName(_ url: URL) -> String {
        (url.host() ?? url.absoluteString).replacingOccurrences(of: "www.", with: "")
    }

    @MainActor
    static func fetch(_ url: URL) async -> Preview {
        let provider = LPMetadataProvider()
        provider.timeout = 12
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return Preview() }
        var image: UIImage?
        if let item = metadata.imageProvider ?? metadata.iconProvider {
            image = await withCheckedContinuation { continuation in
                item.loadObject(ofClass: UIImage.self) { object, _ in continuation.resume(returning: object as? UIImage) }
            }
        }
        return Preview(title: metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines), image: image)
    }
}
