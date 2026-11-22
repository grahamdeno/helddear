import CoreImage
import UIKit
import Vision

/// Finds the face in a person's photo with Apple's Vision framework, on the phone, and makes the round portrait
/// for Home. Results are kept in memory for the session, so swiping through people stays fast.
@MainActor
final class FaceFinder {
    static let shared = FaceFinder()
    private let cache = NSCache<NSString, UIImage>()

    /// The person's own photo, framed on their face: the newest saved photo, else the contact photo.
    func portrait(for person: Person?, side: CGFloat, toned: Bool = false) async -> UIImage? {
        guard let person else { return nil }
        let file = person.photoFiles.last
        let focus = PhotoFocus.box(for: file)
        let key = "\(person.id.uuidString)-\(file ?? "contact")-\(Int(side))-\(toned)-\(PhotoFocus.tag(focus))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let source = PhotoStore.load(file) ?? ContactsService.shared.photo(contactID: person.contactID) else { return nil }
        // Draw upright and smaller first, here (UIKit drawing stays on the main thread): Vision runs faster and the
        // photo's orientation can't go wrong. Finding the face and cropping run off the main thread.
        guard let upright = Self.upright(source) else { return nil }
        let cropped = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let face = Self.cropOnFace(upright, focus: focus) else { return nil }
            return toned ? Self.warmTone(face) : face
        }.value
        let made = cropped.map { UIImage(cgImage: $0) }
        if let made { cache.setObject(made, forKey: key) }
        return made
    }

    /// The faces in a photo, as boxes in its own proportions (0 to 1, top-left origin), largest first, for choosing
    /// who the photo centers on.
    func faces(in image: UIImage) async -> [CGRect] {
        guard let upright = Self.upright(image) else { return [] }
        return await Task.detached(priority: .userInitiated) { () -> [CGRect] in
            let request = VNDetectFaceRectanglesRequest()
            try? VNImageRequestHandler(cgImage: upright, orientation: .up).perform([request])
            return (request.results ?? []).map { r in
                CGRect(x: r.boundingBox.minX, y: 1 - r.boundingBox.maxY, width: r.boundingBox.width, height: r.boundingBox.height)
            }
            .sorted { $0.width * $0.height > $1.width * $1.height }
        }.value
    }

    /// The user's own photo (You page), framed on the face, for an anniversary that's theirs.
    func yourPortrait(side: CGFloat, toned: Bool = false) async -> UIImage? {
        guard let file = YouProfile.photoFile else { return nil }
        let key = "you-\(file)-\(Int(side))-\(toned)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let source = PhotoStore.load(file), let upright = Self.upright(source) else { return nil }
        let cropped = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let face = Self.cropOnFace(upright) else { return nil }
            return toned ? Self.warmTone(face) : face
        }.value
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
        let focus = PhotoFocus.box(for: person.photoFiles.last)
        let cropped = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            let size = CGSize(width: upright.width, height: upright.height)
            let face = focus.map { PhotoFocus.pixels($0, imageSize: size) } ?? Self.face(in: upright)
            let rect = FaceFrame.bannerRect(face: face, imageSize: size, aspect: aspect)
            return upright.cropping(to: rect.integral)
        }.value
        return cropped.map { UIImage(cgImage: $0) }
    }

    /// Any picked photo, cropped to a shape with the face placed (the same framing as a person's photo).
    func banner(of image: UIImage, aspect: CGFloat) async -> UIImage? {
        guard let upright = Self.upright(image, longest: 1600) else { return nil }
        let cropped = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            let size = CGSize(width: upright.width, height: upright.height)
            return upright.cropping(to: FaceFrame.bannerRect(face: Self.face(in: upright), imageSize: size, aspect: aspect).integral)
        }.value
        return cropped.map { UIImage(cgImage: $0) }
    }

    /// A picked photo, upright, with the face-placed crop for a shape, so the person can slide the crop to place the
    /// photo themselves (Graham, Nov 21, 2026).
    func framing(of image: UIImage, aspect: CGFloat) async -> (image: CGImage, rect: CGRect)? {
        guard let upright = Self.upright(image, longest: 1600) else { return nil }
        let rect = await Task.detached(priority: .userInitiated) { () -> CGRect in
            FaceFrame.bannerRect(face: Self.face(in: upright), imageSize: CGSize(width: upright.width, height: upright.height),
                                 aspect: aspect).integral
        }.value
        return (upright, rect)
    }

    /// One of a person's saved photos, upright, with the crop for a shape around the chosen focus (PhotoFocus) or the
    /// largest face: the same start the card had before, now with a crop the user can slide (Nov 22, 2026).
    func framing(file: String, aspect: CGFloat) async -> (image: CGImage, rect: CGRect)? {
        guard let source = PhotoStore.load(file), let upright = Self.upright(source, longest: 1600) else { return nil }
        let focus = PhotoFocus.box(for: file)
        let rect = await Task.detached(priority: .userInitiated) { () -> CGRect in
            let size = CGSize(width: upright.width, height: upright.height)
            let face = focus.map { PhotoFocus.pixels($0, imageSize: size) } ?? Self.face(in: upright)
            return FaceFrame.bannerRect(face: face, imageSize: size, aspect: aspect).integral
        }.value
        return (upright, rect)
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

    /// The photo in the app's own two tones, dark ink to warm stone, so any photo sits calmly on the page and text
    /// near it reads the same (Home's medallion). Made on the phone with Core Image.
    nonisolated private static func warmTone(_ cg: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cg)
        guard let mono = CIFilter(name: "CIColorControls", parameters: [kCIInputImageKey: input, kCIInputSaturationKey: 0, kCIInputContrastKey: 1.08]),
              let duo = CIFilter(name: "CIFalseColor", parameters: [
                kCIInputImageKey: mono.outputImage as Any,
                "inputColor0": CIColor(red: 0.11, green: 0.094, blue: 0.082),
                "inputColor1": CIColor(red: 0.925, green: 0.886, blue: 0.824)
              ]),
              let out = duo.outputImage else { return cg }
        return CIContext(options: nil).createCGImage(out, from: input.extent) ?? cg
    }

    nonisolated private static func cropOnFace(_ cg: CGImage, focus: CGRect? = nil) -> CGImage? {
        let size = CGSize(width: cg.width, height: cg.height)
        let chosen = focus.map { PhotoFocus.pixels($0, imageSize: size) } ?? face(in: cg)
        let square = FaceFrame.portraitSquare(face: chosen, imageSize: size)
        return cg.cropping(to: square.integral)
    }
}
