import SwiftUI
import UIKit
import Vision

/// A photo that fills its space like scaledToFill, but placed on the face (Nov 21, 2026): the face is centered across
/// and sits a little above the middle, so a crop never cuts off a head. Faces are found on the phone by Vision and
/// remembered per photo. With no face, it fills from the center like before.
struct FaceFillImage: View {
    let image: UIImage
    /// How far down the space the face's middle sits (0 top, 1 bottom).
    var faceY: CGFloat = 0.4
    /// A focus the user chose for this photo (PhotoFocus), used instead of the largest face.
    var chosen: CGRect? = nil

    var body: some View {
        GeometryReader { geo in
            let box = geo.size
            let size = image.size
            let scale = max(box.width / max(size.width, 1), box.height / max(size.height, 1))
            let drawn = CGSize(width: size.width * scale, height: size.height * scale)
            let focus = chosen.map { CGPoint(x: $0.midX, y: $0.midY) } ?? FaceFocus.center(of: image) ?? CGPoint(x: 0.5, y: 0.5)
            let x = min(0, max(box.width - drawn.width, box.width / 2 - focus.x * drawn.width))
            let y = min(0, max(box.height - drawn.height, box.height * (focus == CGPoint(x: 0.5, y: 0.5) ? 0.5 : faceY) - focus.y * drawn.height))
            Image(uiImage: image).resizable()
                .frame(width: drawn.width, height: drawn.height)
                .offset(x: x, y: y)
        }
        .clipped()
    }
}

/// Where the face is in a photo, as a point from the top left in 0 to 1. Found once per photo (by a small
/// fingerprint of its pixels), on a small copy so it's quick. Thread-safe.
enum FaceFocus {
    private static let cache = NSCache<NSString, NSValue>()
    private static let none = NSValue(cgPoint: CGPoint(x: -1, y: -1))

    static func center(of image: UIImage) -> CGPoint? {
        guard let small = downscaled(image, side: 256) else { return nil }
        let key = fingerprint(small, size: image.size) as NSString
        if let hit = cache.object(forKey: key) {
            return hit == none ? nil : hit.cgPointValue
        }
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: small, orientation: .up).perform([request])
        let size = CGSize(width: small.width, height: small.height)
        let faces = (request.results ?? []).map { FaceFrame.pixelRect(normalized: $0.boundingBox, imageSize: size) }
        guard let face = FaceFrame.largest(faces) else { cache.setObject(none, forKey: key); return nil }
        let point = CGPoint(x: face.midX / size.width, y: face.midY / size.height)
        cache.setObject(NSValue(cgPoint: point), forKey: key)
        return point
    }

    /// An upright small copy: drawing applies the photo's orientation.
    private static func downscaled(_ image: UIImage, side: CGFloat) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, side / longest)
        let w = max(1, Int(image.size.width * scale)), h = max(1, Int(image.size.height * scale))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        UIGraphicsPushContext(ctx)
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        UIGraphicsPopContext()
        return ctx.makeImage()
    }

    private static func fingerprint(_ cg: CGImage, size: CGSize) -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        if let ctx = CGContext(data: &bytes, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 8,
                               space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) {
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return "\(Int(size.width))x\(Int(size.height))-" + bytes.map { String($0 >> 4, radix: 16) }.joined()
    }
}
