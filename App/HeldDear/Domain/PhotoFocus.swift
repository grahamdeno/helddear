import CoreGraphics
import Foundation

/// Who or what a person's photo centers on, when the user chooses (Graham, Nov 22, 2026): a face out of several, or
/// any spot they tap. Kept as a box in the photo's own proportions (0 to 1, top-left origin), per photo file, in the
/// settings that sync through iCloud. Without one, the largest face is used, as before.
enum PhotoFocus {
    static let key = "photoFocus"

    static func box(for file: String?, _ d: UserDefaults = .standard) -> CGRect? {
        guard let file, let all = d.dictionary(forKey: key) as? [String: [Double]], let v = all[file], v.count == 4 else { return nil }
        return CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
    }

    static func set(_ box: CGRect?, for file: String, _ d: UserDefaults = .standard) {
        var all = (d.dictionary(forKey: key) as? [String: [Double]]) ?? [:]
        all[file] = box.map { [Double($0.minX), Double($0.minY), Double($0.width), Double($0.height)] }
        d.set(all, forKey: key)
    }

    /// A tapped spot as a box: a face-sized square around it (by default a quarter of the photo's shorter side;
    /// smaller after zooming in on a group).
    static func box(around point: CGPoint, imageSize: CGSize, share: CGFloat = 0.25) -> CGRect {
        let side = share * min(imageSize.width, imageSize.height)
        let w = side / max(imageSize.width, 1), h = side / max(imageSize.height, 1)
        return CGRect(x: min(max(0, point.x - w / 2), 1 - w), y: min(max(0, point.y - h / 2), 1 - h), width: w, height: h)
    }

    /// Fine-tuning (Nov 22, 2026): a drag on the round preview moves the photo with the finger, so the box moves the
    /// other way. The preview shows a square about twice the box's longer side. Kept inside the photo.
    static func nudged(_ box: CGRect, by t: CGSize, previewSide: CGFloat, imageSize: CGSize) -> CGRect {
        let sidePx = max(box.width * imageSize.width, box.height * imageSize.height) / 0.5
        let dx = -t.width / max(previewSide, 1) * sidePx / max(imageSize.width, 1)
        let dy = -t.height / max(previewSide, 1) * sidePx / max(imageSize.height, 1)
        return inside(box.offsetBy(dx: dx, dy: dy))
    }

    /// The box made `factor` times the size of `base`, around the box's own center: above 1 is wider, below is closer.
    static func resized(_ box: CGRect, base: CGRect, factor: CGFloat) -> CGRect {
        let w = min(1, base.width * factor), h = min(1, base.height * factor)
        return inside(CGRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h))
    }

    static func inside(_ r: CGRect) -> CGRect {
        CGRect(x: min(max(0, r.minX), 1 - r.width), y: min(max(0, r.minY), 1 - r.height), width: r.width, height: r.height)
    }

    /// The box in pixels, for framing.
    static func pixels(_ box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(x: box.minX * imageSize.width, y: box.minY * imageSize.height,
               width: box.width * imageSize.width, height: box.height * imageSize.height)
    }

    /// Text for a cache key, so a new focus makes a new portrait.
    static func tag(_ box: CGRect?) -> String {
        guard let b = box else { return "auto" }
        return String(format: "%.3f,%.3f,%.3f", b.midX, b.midY, b.width)
    }
}
