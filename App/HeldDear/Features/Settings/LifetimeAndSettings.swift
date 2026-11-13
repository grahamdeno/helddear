import SwiftUI
import UIKit

/// The Held Dear Lifetime offer. Reached only from Settings, a locked card design, or once after the
/// first yearly line. The close button shows at once. No countdown timers, no blur, no nagging.
struct LifetimeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchases = Purchases.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Brand.action).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CirclesMark(size: 64).frame(maxWidth: .infinity).padding(.top, 8)
                    if purchases.hasLifetime {
                        Text("Thank you. It's all yours.").textStyle(.display).frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Held Dear Lifetime").textStyle(.display)
                        Text("Everything that keeps you from missing anyone stays free. Lifetime adds more ways to make it personal.")
                            .textStyle(.body, color: Brand.ink.opacity(0.85))
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        benefit("rectangle.portrait.on.rectangle.portrait", "Every card design, in your own words")
                        benefit("lock.iphone", "A countdown on your Lock Screen")
                        benefit("clock.arrow.circlepath", "1 year ago, and a yearly keepsake to share")
                        benefit("calendar.badge.plus", "Anniversaries, holidays and life moments, not just birthdays")
                        benefit("sparkles", "Gift ideas and card words, written on your iPhone")
                        benefit("photo.on.rectangle", "Every year of birthday photos, from your library")
                    }
                    .padding(Brand.space4 + 4)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                }
                .padding(.horizontal, Brand.space5)
            }
            VStack(spacing: Brand.space2) {
                if purchases.hasLifetime {
                    PrimaryButton(title: "Done") { dismiss() }
                } else {
                    PrimaryButton(title: purchases.isWorking ? "One moment…" : "Get Lifetime · \(purchases.priceText)") {
                        Task { await purchases.buy() }
                    }
                    .disabled(purchases.isWorking)
                    Text("One payment. No subscription. Shared with your family.")
                        .textStyle(.caption, color: Brand.inkMuted).multilineTextAlignment(.center)
                    TextLink(title: "Restore purchase") { Task { await purchases.restore() } }
                }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, 12)
        }
        .background(Brand.page.ignoresSafeArea())
        .alert(purchases.message ?? "", isPresented: Binding(get: { purchases.message != nil }, set: { if !$0 { purchases.message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Brand.action).frame(width: 28)
                .accessibilityHidden(true)
            Text(text).textStyle(.bodyStrong).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The app's three-circle mark, drawn in code.
/// The Held Dear mark (same as the app icon): a horizon line, two quiet marks and one oxblood mark rising
/// from a dot. Kept under its old name so callers don't change.
struct CirclesMark: View {
    var size: CGFloat
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, y = w * 0.63
            ctx.fill(Path(CGRect(x: w * 0.13, y: y - w * 0.013, width: w * 0.74, height: w * 0.026)), with: .color(Brand.ink))
            for (x, h) in [(0.29, 0.15), (0.71, 0.23)] as [(CGFloat, CGFloat)] {
                ctx.fill(Path(CGRect(x: w * x - w * 0.011, y: y - w * h, width: w * 0.022, height: w * h)), with: .color(Brand.ink))
            }
            ctx.fill(Path(CGRect(x: w * 0.47 - w * 0.018, y: y - w * 0.37, width: w * 0.036, height: w * 0.37)), with: .color(Brand.action))
            let r = w * 0.058
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.47 - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Brand.action))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Settings: Lifetime, people, Lock Screen privacy, and what stays on the phone.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var purchases = Purchases.shared
    @State private var showLifetime = false
    @State private var addingFromContacts = false
    @AppStorage("lockScreenInitialsOnly", store: UserDefaults(suiteName: AppGroup.identifier)) private var initialsOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings").textStyle(.title).accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Held Dear Lifetime")
                    OptionRow(title: purchases.hasLifetime ? "Lifetime is on" : "Held Dear Lifetime",
                              caption: purchases.hasLifetime ? "Thank you" : "Every card design, Lock Screen, look-back · \(purchases.priceText)") {
                        showLifetime = true
                    }
                }
                if purchases.isTestBuild {
                    VStack(alignment: .leading, spacing: Brand.space2) {
                        Eyebrow(text: "TestFlight only")
                        Toggle(isOn: Binding(get: { purchases.hasLifetime },
                                             set: { on in Task { await purchases.setTestOverride(on) } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lifetime for testing").textStyle(.bodyStrong)
                                Text("Turns the paid features on without buying. Not in the App Store version. A sandbox purchase also works and is free.")
                                    .textStyle(.caption, color: Brand.inkMuted)
                            }
                        }
                        .tint(Brand.action)
                        .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "People")
                    OptionRow(title: "Add from contacts", caption: "Share more people with Held Dear") { addingFromContacts = true }
                    OptionRow(title: "Add a birthday", caption: "Type a name and a date") { model.route = .addBirthday("") }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Lock Screen")
                    Toggle(isOn: $initialsOnly) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Initials only").textStyle(.bodyStrong)
                            Text("The Lock Screen widget shows initials instead of names").textStyle(.caption, color: Brand.inkMuted)
                        }
                    }
                    .tint(Brand.action)
                    .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    .onChange(of: initialsOnly) { _, _ in model.writeSnapshots() }
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Alerts")
                    OptionRow(title: model.notificationsAllowed ? "Alerts are on" : "Alerts are off",
                              caption: "Change them in the Settings app") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Text("Everything you add stays on this iPhone. Held Dear has no account. Purchases go through Apple. A mailed card sends only its message and the two addresses to Handwrytten, to mail it.")
                    .textStyle(.caption, color: Brand.inkMuted)
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                    .textStyle(.caption, color: Brand.inkMuted)
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 8)
        }
        .background(Brand.page.ignoresSafeArea())
        .sheet(isPresented: $showLifetime) { LifetimeView() }
        .addFromContacts(isPresented: $addingFromContacts)
    }
}
