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

    /// A tapped spot as a box: a face-sized square around it (a quarter of the photo's shorter side).
    static func box(around point: CGPoint, imageSize: CGSize) -> CGRect {
        let side = 0.25 * min(imageSize.width, imageSize.height)
        let w = side / max(imageSize.width, 1), h = side / max(imageSize.height, 1)
        return CGRect(x: min(max(0, point.x - w / 2), 1 - w), y: min(max(0, point.y - h / 2), 1 - h), width: w, height: h)
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
