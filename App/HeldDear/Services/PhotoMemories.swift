import Photos
import UIKit

/// Photos taken around a person's past birthdays, read from the Photos library on this iPhone.
/// Nothing is copied unless the user picks a photo for the card; nothing leaves the phone.
@MainActor
final class PhotoMemories: ObservableObject {
    static let shared = PhotoMemories()

    struct Year: Identifiable {
        let year: Int
        let assets: [PHAsset]
        var id: Int { year }
    }

    @Published private(set) var status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var canRead: Bool { status == .authorized || status == .limited }

    func requestAccess() async {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// Up to `perYear` photos (newest first) for each past birthday that has any.
    func years(month: Int, day: Int, now: Date = Date(), perYear: Int = 6) -> [Year] {
        guard canRead else { return [] }
        return PhotoWindows.birthdays(month: month, day: day, now: now).compactMap { w in
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@ AND mediaType == %d",
                                            w.start as NSDate, w.end as NSDate, PHAssetMediaType.image.rawValue)
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = perYear
            let result = PHAsset.fetchAssets(with: options)
            guard result.count > 0 else { return nil }
            var assets: [PHAsset] = []
            result.enumerateObjects { a, _, _ in assets.append(a) }
            return Year(year: w.year, assets: assets)
        }
    }

    func thumbnail(_ asset: PHAsset, side: CGFloat) async -> UIImage? {
        await image(asset, size: CGSize(width: side * 2, height: side * 2))
    }

    func fullImage(_ asset: PHAsset) async -> UIImage? {
        await image(asset, size: CGSize(width: 1600, height: 1600))
    }

    /// High-quality delivery calls back once. iCloud-only originals are skipped (no network).
    private func image(_ asset: PHAsset, size: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast
        return await withCheckedContinuation { cont in
            var resumed = false
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: image)
            }
        }
    }
}
