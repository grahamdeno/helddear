import Foundation
import UIKit

/// Digital cards the user saves (Graham, Nov 21, 2026): drafts to finish later and cards already made, to open,
/// change and share again. Kept in the app's own folder on this iPhone, one folder per card with its words and the
/// photos it uses. Nothing is uploaded.
struct SavedCard: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var occasionID: String
    var heading: String
    var line: String
    var signature: String
    var story: Bool
    var moving: Bool
    /// Where each photo is cropped, in that photo's pixels.
    var crops: [CGRect]
    /// False: a draft. True: made and shared at least once.
    var made: Bool
    var updated: Date
}

enum CardDrafts {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Cards", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func dir(_ id: UUID) -> URL { folder.appending(path: id.uuidString, directoryHint: .isDirectory) }

    /// Every saved card, newest first.
    static func all() -> [SavedCard] {
        let dirs = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        return dirs.compactMap { d in
            guard let data = try? Data(contentsOf: d.appending(path: "card.json")) else { return nil }
            return try? decoder.decode(SavedCard.self, from: data)
        }
        .sorted { $0.updated > $1.updated }
    }

    /// Saves the card's words and its photos (upright, as picked).
    static func save(_ card: SavedCard, photos: [CGImage]) {
        let d = dir(card.id)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(card) { try? data.write(to: d.appending(path: "card.json"), options: .atomic) }
        let old = (try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? []
        for f in old where f.lastPathComponent.hasPrefix("photo-") { try? FileManager.default.removeItem(at: f) }
        for (i, cg) in photos.enumerated() {
            try? UIImage(cgImage: cg).jpegData(compressionQuality: 0.88)?
                .write(to: d.appending(path: "photo-\(i).jpg"), options: .atomic)
        }
    }

    static func photos(_ card: SavedCard) -> [CGImage] {
        (0..<card.crops.count).compactMap { i in
            guard let data = try? Data(contentsOf: dir(card.id).appending(path: "photo-\(i).jpg")) else { return nil }
            return UIImage(data: data)?.cgImage
        }
    }

    /// A small picture of the card's first photo, for the list.
    static func thumbnail(_ card: SavedCard) -> UIImage? {
        guard let first = photos(card).first, let crop = card.crops.first, let cg = first.cropping(to: crop) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func delete(_ card: SavedCard) {
        try? FileManager.default.removeItem(at: dir(card.id))
    }
}

extension GreetingCard.Occasion {
    init?(id: String) {
        if id == "own" { self = .ownWords; return }
        if id.hasPrefix("h-"), let t = OccasionType(rawValue: String(id.dropFirst(2))) { self = .holiday(t); return }
        if id.hasPrefix("r-"), let r = CardReason(rawValue: String(id.dropFirst(2))) { self = .reason(r); return }
        return nil
    }
}
