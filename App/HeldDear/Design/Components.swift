import SwiftUI
import UIKit

// Components from the Hearth design system README. Separation comes from card against page, never shadows.

/// A flow screen: question at the top, choices below, the one action at the bottom.
struct FlowScreen<Content: View, Footer: View>: View {
    var onClose: (() -> Void)?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            if let onClose {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Brand.action)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.horizontal, Brand.space5 - 12)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Brand.space5)
                    .padding(.top, onClose == nil ? 24 : 4)
                    .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: Brand.space2) { footer }
                .padding(.horizontal, Brand.space5)
                .padding(.bottom, 12)
        }
        .background(Brand.page.ignoresSafeArea())
    }
}

extension FlowScreen where Footer == EmptyView {
    init(onClose: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.onClose = onClose
        self.content = content()
        self.footer = EmptyView()
    }
}

/// The question at the top of a flow screen, with an optional tag above and a line below.
struct Question: View {
    var tag: String?
    var title: String
    var subtitle: String?
    var style: TypeStyle = .display

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            if let tag { Tag(text: tag) }
            Text(title).textStyle(style).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).textStyle(.callout, color: Brand.inkMuted).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(TypeStyle.callout.font.weight(.heavy))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(Brand.onAction)
                .background(Brand.action, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

struct SecondaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(TypeStyle.callout.font.weight(.heavy))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 12)
                .foregroundStyle(Brand.action)
                .background(Brand.card, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

struct TextLink: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(TypeStyle.callout.font.weight(.bold))
                .foregroundStyle(Brand.action)
                .padding(.vertical, 11).padding(.horizontal, 8)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View { Text(text).textStyle(.eyebrow, color: Brand.inkMuted).accessibilityAddTraits(.isHeader) }
}

/// A card row that is one button: title, optional caption, coral chevron disc.
struct OptionRow<Leading: View, Trailing: View>: View {
    var title: String
    var caption: String?
    var action: () -> Void
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        Button(action: action) {
            HStack(spacing: Brand.space3) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.bodyStrong).multilineTextAlignment(.leading)
                    if let caption { Text(caption).textStyle(.caption, color: Brand.inkMuted).multilineTextAlignment(.leading) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
            .frame(minHeight: 64)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

extension OptionRow where Leading == EmptyView, Trailing == ChevronDisc {
    init(title: String, caption: String? = nil, action: @escaping () -> Void) {
        self.init(title: title, caption: caption, action: action, leading: { EmptyView() }, trailing: { ChevronDisc() })
    }
}

struct ChevronDisc: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(width: 32, height: 32)
            .background(Brand.accent, in: Circle())
            .accessibilityHidden(true)
    }
}

struct CheckBadge: View {
    var size: CGFloat = 22
    var body: some View {
        Image(systemName: "checkmark").font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
            .foregroundStyle(Brand.onAction)
            .frame(width: size, height: size)
            .background(Brand.action, in: Circle())
            .accessibilityHidden(true)
    }
}

/// One callout line on a card strip, such as "Last year: flowers and a call".
struct ContextLine: View {
    var text: String
    var body: some View {
        Text(text).textStyle(.callout, color: Brand.ink.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = Brand.space4
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }
}

extension Face {
    init(person: Person, size: CGFloat = 44, fill: Color? = nil) {
        self.init(name: person.name, initials: person.initials,
                  image: ContactsService.shared.thumbnail(contactID: person.contactID) ?? PhotoStore.load(person.photoFiles.last),
                  size: size, fill: fill)
    }
}

/// A placeholder tile for a photo that isn't there, or the photo itself.
struct PhotoTile: View {
    var image: UIImage?
    var label: String
    var height: CGFloat = 150
    var radius: CGFloat = Brand.radiusMd

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Brand.faceFills[0]
                Text(label).textStyle(.caption, color: Brand.ink.opacity(0.8)).multilineTextAlignment(.center).padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityLabel(label)
    }
}

/// The one-line input with a dictation button.
struct LineField: View {
    var label: String
    @Binding var text: String
    var placeholder: String = ""
    var showsDictation = true
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool
    @StateObject private var dictation = Dictation()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(TypeStyle.caption.font.weight(.bold)).foregroundStyle(Brand.inkMuted)
            HStack(spacing: 10) {
                TextField(placeholder, text: $text)
                    .font(TypeStyle.hasNunito ? Font.custom("Nunito", size: 19, relativeTo: .body).weight(.bold)
                                              : Font.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.ink)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
                if showsDictation {
                    Button {
                        if dictation.isListening { dictation.stop() } else { focused = false; dictation.start { text = $0 } }
                    } label: {
                        Image(systemName: dictation.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Brand.onAction)
                            .frame(width: 44, height: 44)
                            .background(Brand.action, in: Circle())
                    }
                    .accessibilityLabel(dictation.isListening ? "Stop dictating" : "Dictate")
                }
            }
            .padding(.leading, Brand.space4).padding(.trailing, 8).padding(.vertical, 8)
            .frame(minHeight: 60)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous)
                .stroke(focused || dictation.isListening ? Brand.action : Brand.line, lineWidth: 2))
            .onTapGesture { focused = true }
        }
        .onDisappear { dictation.stop() }
    }
}
