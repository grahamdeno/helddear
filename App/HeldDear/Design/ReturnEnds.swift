import SwiftUI
import UIKit

extension View {
    /// For a one-line answer that wraps onto more lines as it grows: the keyboard's return or checkmark finishes it
    /// and closes the keyboard instead of starting a new line (Graham, Nov 22, 2026). Pasted line breaks become spaces.
    func returnEnds(_ text: Binding<String>, onEnd: @escaping () -> Void = {}) -> some View {
        submitLabel(.done)
            .onChange(of: text.wrappedValue) { _, value in
                guard value.contains("\n") else { return }
                let ended = value.hasSuffix("\n")
                text.wrappedValue = value.replacingOccurrences(of: "\n", with: ended ? "" : " ")
                    .trimmingCharacters(in: .newlines)
                if ended {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    onEnd()
                }
            }
    }
}
