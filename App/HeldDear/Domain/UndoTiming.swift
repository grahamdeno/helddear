import UIKit

/// How long Undo stays, and saying it out loud (Fable's audit UX-8, Nov 24, 2026): eight seconds, twenty with
/// VoiceOver on, and VoiceOver announces "… removed. Undo is available."
enum UndoTiming {
    static func seconds(voiceOver: Bool) -> Double { voiceOver ? 20 : 8 }

    static func announcement(_ text: String) -> String { "\(text). Undo is available." }

    @MainActor static func announce(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: announcement(text))
    }
}
