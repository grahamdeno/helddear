import UIKit
import Vision

/// Finds the face in a person's photo with Apple's Vision framework, on the phone, and makes the round portrait
/// for Home. Results are kept in memory for the session, so swiping through people stays fast.
@MainActor
final class FaceFinder {
    static let shared = FaceFinder()
    private let cache = NSCache<NSString, UIImage>()

    /// The person's own photo, framed on their face: the newest saved photo, else the contact photo.
    func portrait(for person: Person?, side: CGFloat) async -> UIImage? {
        guard let person else { return nil }
        let file = person.photoFiles.last
        let key = "\(person.id.uuidString)-\(file ?? "contact")-\(Int(side))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let source = PhotoStore.load(file) ?? ContactsService.shared.photo(contactID: person.contactID) else { return nil }
        // Draw upright and smaller first, here (UIKit drawing stays on the main thread): Vision runs faster and the
        // photo's orientation can't go wrong. Finding the face and cropping run off the main thread.
        guard let upright = Self.upright(source) else { return nil }
        let cropped = await Task.detached(priority: .userInitiated) { Self.cropOnFace(upright) }.value
        let made = cropped.map { UIImage(cgImage: $0) }
        if let made { cache.setObject(made, forKey: key) }
        return made
    }

    /// The person's photo cropped to a shape (width / height) with the face placed for a share image. Larger than
    /// the portrait: up to 1600 pixels across.
    func banner(for person: Person?, aspect: CGFloat) async -> UIImage? {
        guard let person,
              let source = PhotoStore.load(person.photoFiles.last) ?? ContactsService.shared.photo(contactID: person.contactID),
              let upright = Self.upright(source, longest: 1600) else { return nil }
        let cropped = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            let size = CGSize(width: upright.width, height: upright.height)
            let rect = FaceFrame.bannerRect(face: Self.face(in: upright), imageSize: size, aspect: aspect)
            return upright.cropping(to: rect.integral)
        }.value
        return cropped.map { UIImage(cgImage: $0) }
    }

    nonisolated private static func face(in cg: CGImage) -> CGRect? {
        let size = CGSize(width: cg.width, height: cg.height)
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([request])
        return FaceFrame.largest((request.results ?? []).map { FaceFrame.pixelRect(normalized: $0.boundingBox, imageSize: size) })
    }

    private static func upright(_ image: UIImage, longest limit: CGFloat = 1024) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, limit / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    nonisolated private static func cropOnFace(_ cg: CGImage) -> CGImage? {
        let size = CGSize(width: cg.width, height: cg.height)
        let square = FaceFrame.portraitSquare(face: face(in: cg), imageSize: size)
        return cg.cropping(to: square.integral)
    }
}
