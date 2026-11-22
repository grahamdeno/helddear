import CoreGraphics
import Foundation

/// Choosing and placing the photo on a card, the same way on the share card and the digital card (Graham, Nov 22,
/// 2026): a row of photos with the chosen one marked, and a drag on the preview to place it. Plain rules, unit tested.
enum CardPhotos {
    /// The person's photos for the row: the top photo first (it's what the card starts with), then the past year's,
    /// newest first, then the rest, newest first, then photos with no date. Choosing opens on this year.
    static func order(files: [String], top: String?, now: Date = Date(), calendar: Calendar = .current) -> [String] {
        let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let rest = files.filter { $0 != top }
        let dated = rest.compactMap { f in ChosenPhotos.taken(f, calendar: calendar).map { (f, $0) } }
            .sorted { $0.1 > $1.1 }
        let recent = dated.filter { $0.1 >= yearAgo }.map(\.0)
        let older = dated.filter { $0.1 < yearAgo }.map(\.0)
        let undated = rest.filter { ChosenPhotos.taken($0, calendar: calendar) == nil }.reversed()
        return (top.map { [$0] } ?? []) + recent + older + undated
    }

    /// Slides a crop by a drag on a preview drawn `canvasWidth` points wide and shown at `scale`, kept inside the photo.
    static func slide(_ start: CGRect, imageSize: CGSize, by translation: CGSize, scale: CGFloat,
                      canvasWidth: CGFloat = 390) -> CGRect {
        let pixelsPerPoint = start.width / canvasWidth
        var rect = start
        rect.origin.x -= translation.width / max(scale, 0.01) * pixelsPerPoint
        rect.origin.y -= translation.height / max(scale, 0.01) * pixelsPerPoint
        rect.origin.x = min(max(0, rect.origin.x), imageSize.width - rect.width)
        rect.origin.y = min(max(0, rect.origin.y), imageSize.height - rect.height)
        return rect.integral
    }

    /// The words under the preview, the same on both cards.
    static func placeHint(photoCount: Int) -> String {
        photoCount > 1 ? "Drag a photo to place it. Pick another above." : "Drag the photo to place it."
    }
}
