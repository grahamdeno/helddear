import SwiftUI
import WidgetKit

/// The one v1 widget: next person up.
@main
struct HeldDearWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPersonWidget()
        LockScreenWidget()
    }
}

struct NextPersonEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
}

struct NextPersonProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextPersonEntry {
        NextPersonEntry(date: Date(), snapshot: WidgetSnapshot(next: [
            .init(momentID: UUID(), name: "Mom", occasion: "Birthday", dueDate: Date().addingTimeInterval(9 * 86400), detail: "turning 70"),
        ], writtenAt: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (NextPersonEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : NextPersonEntry(date: Date(), snapshot: read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPersonEntry>) -> Void) {
        // Countdowns change at midnight; refresh then.
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [NextPersonEntry(date: Date(), snapshot: read())], policy: .after(tomorrow)))
    }

    private func read() -> WidgetSnapshot? { AppGroup.read(WidgetSnapshot.self, from: AppGroup.widgetURL) }
}

struct NextPersonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPerson", provider: NextPersonProvider()) { entry in
            NextPersonView(entry: entry)
                .containerBackground(Brand.page, for: .widget)
        }
        .configurationDisplayName("Next person up")
        .description("Whose day is coming, and how long until it.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Lock Screen (Held Dear Lifetime): rectangular and circular. Never shows a missed birthday.
struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockScreen", provider: NextPersonProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Next person up")
        .description("A countdown on your Lock Screen. Part of Held Dear Lifetime.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

struct LockScreenView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NextPersonEntry

    private var shared: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }

    var body: some View {
        let hasLifetime = shared?.bool(forKey: "hasLifetime") ?? false
        let initialsOnly = shared?.bool(forKey: "lockScreenInitialsOnly") ?? false
        let today = Calendar.current.startOfDay(for: entry.date)
        let next = (entry.snapshot?.next ?? []).first { $0.dueDate >= today }

        if !hasLifetime {
            VStack(alignment: .leading, spacing: 2) {
                Text("Held Dear").font(.headline)
                Text("Part of Held Dear Lifetime").font(.caption)
            }
            .widgetURL(URL(string: "helddear://lifetime"))
        } else if let e = next {
            let days = Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: e.dueDate)).day ?? 0
            let name = initialsOnly ? initials(e.name) : e.name
            if family == .accessoryCircular {
                if days == 0 {
                    VStack(spacing: 0) {
                        Image(systemName: "gift.fill").font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("Today").font(.system(size: 10, weight: .heavy, design: .rounded))
                    }
                } else {
                    Gauge(value: Double(max(0, 21 - min(days, 21))), in: 0...21) {
                        Text(initials(e.name))
                    } currentValueLabel: {
                        Text("\(days)").font(.system(size: 18, weight: .heavy, design: .rounded))
                    }
                    .gaugeStyle(.accessoryCircular)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 17, weight: .heavy, design: .rounded)).lineLimit(1)
                    Text(e.soonLine ?? "\(days == 1 ? "1 day" : "\(days) days") · \(e.dueDate.formatted(.dateTime.weekday(.wide)))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(URL(string: "helddear://moment?id=\(e.momentID.uuidString)"))
            }
        } else {
            Text("Held Dear").font(.headline)
        }
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

struct NextPersonView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NextPersonEntry

    var body: some View {
        let upcoming = (entry.snapshot?.next ?? []).filter { $0.dueDate >= Calendar.current.startOfDay(for: entry.date) }
        if let first = upcoming.first {
            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(upcoming.prefix(2).enumerated()), id: \.offset) { _, e in row(e) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Face(name: first.name, initials: initials(first.name), image: nil, size: 40)
                    Spacer(minLength: 0)
                    Text(first.name).textStyle(.headline).lineLimit(1)
                    Text(first.detail.map { "\(first.occasion) · \($0)" } ?? first.occasion).textStyle(.caption, color: Brand.inkMuted).lineLimit(1)
                    Tag(text: countdown(first.dueDate))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .widgetURL(URL(string: "helddear://moment?id=\(first.momentID.uuidString)"))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Held Dear").textStyle(.headline)
                Text("Add your people and the next one shows here.").textStyle(.caption, color: Brand.inkMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func row(_ e: WidgetSnapshot.Entry) -> some View {
        Link(destination: URL(string: "helddear://moment?id=\(e.momentID.uuidString)")!) {
            HStack(spacing: 12) {
                Face(name: e.name, initials: initials(e.name), image: nil, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.name).textStyle(.bodyStrong).lineLimit(1)
                    Text(e.detail.map { "\(e.occasion) · \($0)" } ?? e.occasion).textStyle(.caption, color: Brand.inkMuted).lineLimit(1)
                }
                Spacer(minLength: 4)
                Tag(text: countdown(e.dueDate))
            }
        }
    }

    private func countdown(_ due: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: entry.date),
                                                   to: Calendar.current.startOfDay(for: due)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...45: return "in \(days) days"
        default: return "in \(max(1, Int((Double(days) / 30.4).rounded()))) months"
        }
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
