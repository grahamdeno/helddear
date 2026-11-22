import AppIntents
import SwiftUI
import WidgetKit

// Home Screen widgets (approved Nov 21, 2026): small, medium and large "Coming up", and a small holiday widget the
// user points at one holiday. All part of Held Dear Lifetime. They read the snapshot the app writes to the App Group;
// nothing leaves the phone. Faces show only when the user turns them on in the app.

enum WidgetLook {
    static var shared: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }
    static var hasLifetime: Bool { shared?.bool(forKey: "hasLifetime") ?? false }
    static var facesOn: Bool { shared?.bool(forKey: AppGroup.widgetFacesKey) ?? false }

    static func face(_ e: WidgetSnapshot.Entry) -> UIImage? {
        guard facesOn, let id = e.personID, let data = try? Data(contentsOf: AppGroup.faceURL(id)) else { return nil }
        return UIImage(data: data)
    }

    static func days(_ e: WidgetSnapshot.Entry, from now: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now),
                                        to: Calendar.current.startOfDay(for: e.dueDate)).day ?? 0
    }

    static func countdown(_ e: WidgetSnapshot.Entry, from now: Date) -> String {
        let d = days(e, from: now)
        switch d {
        case ...0: return "Today"
        case 1: return "Tomorrow"
        case 2...59: return "\(d) days"
        default: return "\(max(2, Int((Double(d) / 30.4).rounded()))) months"
        }
    }

    /// "2 of 3 ready", "6 people", or "nothing yet". Never red, never overdue.
    static func readiness(_ e: WidgetSnapshot.Entry) -> String {
        var bits: [String] = []
        if let total = e.total, total > 0 { bits.append("\(e.ready ?? 0) of \(total) ready") }
        if let people = e.people, people > 0 { bits.append("\(people) \(people == 1 ? "person" : "people")") }
        return bits.isEmpty ? "nothing yet" : bits.joined(separator: " · ")
    }

    static func initial(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

/// A round face, a holiday star, or an initial on stone; an oxblood ring when there's a plan in progress.
struct WidgetFace: View {
    let entry: WidgetSnapshot.Entry
    var size: CGFloat
    var ringed = false

    var body: some View {
        ZStack {
            Circle().fill(Brand.ringInner)
            if let image = WidgetLook.face(entry) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if entry.isHoliday {
                Image(systemName: "star").font(.system(size: size * 0.38, weight: .light)).foregroundStyle(Brand.inkMuted)
            } else {
                Text(WidgetLook.initial(entry.name)).font(Brand.display(size * 0.42)).foregroundStyle(Brand.inkMuted)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .padding(ringed ? 3 : 0)
        .overlay { if ringed { Circle().strokeBorder(Brand.action, lineWidth: 2) } }
        .accessibilityHidden(true)
    }
}

/// What a free user sees: a quiet card that opens Lifetime.
struct WidgetLifetimeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Held Dear").font(Brand.display(22)).foregroundStyle(Brand.ink)
            Spacer(minLength: 0)
            Text("Part of Held Dear Lifetime").font(.caption.weight(.medium)).foregroundStyle(Brand.inkMuted)
            Text("Tap to see it").font(.caption).foregroundStyle(Brand.action)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "helddear://lifetime"))
    }
}

struct HomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NextPersonEntry

    private var upcoming: [WidgetSnapshot.Entry] {
        (entry.snapshot?.next ?? []).filter { $0.dueDate >= Calendar.current.startOfDay(for: entry.date) }
    }

    var body: some View {
        if !WidgetLook.hasLifetime {
            WidgetLifetimeCard()
        } else if let first = upcoming.first {
            switch family {
            case .systemMedium: medium
            case .systemLarge: large(first)
            default: small(first)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Held Dear").font(Brand.display(22)).foregroundStyle(Brand.ink)
                Text("Add your people and the next day shows here.").font(.caption).foregroundStyle(Brand.inkMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func small(_ e: WidgetSnapshot.Entry) -> some View {
        VStack(spacing: 4) {
            Text(e.dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Brand.inkMuted).lineLimit(1)
            Spacer(minLength: 0)
            WidgetFace(entry: e, size: 46, ringed: (e.total ?? 0) > 0)
            Text(e.name).font(Brand.display(22)).foregroundStyle(Brand.ink).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text("\(WidgetLook.countdown(e, from: entry.date)) · \(WidgetLook.readiness(e))")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.inkMuted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(e.link)
        .accessibilityElement(children: .combine)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COMING UP").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(Brand.inkMuted)
                Spacer()
                Text("Held Dear").font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.action)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(upcoming.prefix(4).enumerated()), id: \.offset) { i, e in
                    Link(destination: e.link) {
                        VStack(spacing: 3) {
                            WidgetFace(entry: e, size: 36, ringed: i == 0 && (e.total ?? 0) > 0)
                            Text(e.name).font(Brand.display(15)).foregroundStyle(Brand.ink).lineLimit(1).minimumScaleFactor(0.7)
                            Text(e.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 10, weight: .medium)).foregroundStyle(Brand.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            Rectangle().fill(Brand.ink.opacity(0.4)).frame(height: 1)
        }
    }

    private func large(_ e: WidgetSnapshot.Entry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("COMING UP").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(Brand.inkMuted)
                Spacer()
                Text("Held Dear").font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.action)
            }
            Link(destination: e.link) {
                HStack(spacing: 12) {
                    WidgetFace(entry: e, size: 54, ringed: (e.total ?? 0) > 0)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(e.name).font(Brand.display(28)).foregroundStyle(Brand.ink).lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(e.isHoliday ? WidgetLook.readiness(e) : e.occasion) · \(e.dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(WidgetLook.countdown(e, from: entry.date))")
                            .font(.caption).foregroundStyle(Brand.inkMuted).lineLimit(1).minimumScaleFactor(0.8)
                        if let step = e.soonLine ?? e.nextStep {
                            Text(step).font(.caption.weight(.medium)).foregroundStyle(Brand.action).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            Rectangle().fill(Brand.line).frame(height: 1)
            ForEach(Array(upcoming.dropFirst().prefix(5).enumerated()), id: \.offset) { _, x in
                Link(destination: x.link) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(x.name).font(Brand.display(18)).foregroundStyle(Brand.ink).lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(x.dueDate.formatted(.dateTime.month(.abbreviated).day())) · \(x.isHoliday || (x.total ?? 0) > 0 ? WidgetLook.readiness(x) : (x.detail ?? WidgetLook.readiness(x)))")
                            .font(.caption).foregroundStyle(Brand.inkMuted).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: The holiday widget

struct HolidayChoice: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Holiday"
    static var defaultQuery = HolidayChoiceQuery()
    var id: String
    var label: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(label)") }
}

struct HolidayChoiceQuery: EntityQuery {
    static func all() -> [HolidayChoice] {
        var seen = Set<String>()
        let holidays = AppGroup.read(WidgetSnapshot.self, from: AppGroup.widgetURL)?.holidays ?? []
        return holidays.compactMap { e in
            guard let raw = e.holidayRaw, seen.insert(raw).inserted else { return nil }
            return HolidayChoice(id: raw, label: e.name)
        }
    }
    func entities(for identifiers: [String]) async throws -> [HolidayChoice] {
        Self.all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [HolidayChoice] { Self.all() }
    func defaultResult() async -> HolidayChoice? { Self.all().first }
}

struct PickHoliday: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Pick a holiday"
    static var description = IntentDescription("The holiday this widget counts down to.")
    @Parameter(title: "Holiday") var holiday: HolidayChoice?
}

struct HolidayEntry: TimelineEntry {
    var date: Date
    var holiday: WidgetSnapshot.Entry?
}

struct HolidayProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HolidayEntry {
        HolidayEntry(date: Date(), holiday: WidgetSnapshot.Entry(
            momentID: UUID(), name: "Christmas", occasion: "Christmas", dueDate: Date().addingTimeInterval(30 * 86400),
            detail: nil, soonLine: nil, holidayRaw: "christmas", year: 2026, ready: 2, total: 5, people: 6))
    }

    func snapshot(for configuration: PickHoliday, in context: Context) async -> HolidayEntry {
        context.isPreview ? placeholder(in: context) : entry(configuration)
    }

    func timeline(for configuration: PickHoliday, in context: Context) async -> Timeline<HolidayEntry> {
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        return Timeline(entries: [entry(configuration)], policy: .after(tomorrow))
    }

    private func entry(_ configuration: PickHoliday) -> HolidayEntry {
        let today = Calendar.current.startOfDay(for: Date())
        let holidays = (AppGroup.read(WidgetSnapshot.self, from: AppGroup.widgetURL)?.holidays ?? []).filter { $0.dueDate >= today }
        let chosen = configuration.holiday.flatMap { pick in holidays.first { $0.holidayRaw == pick.id } } ?? holidays.first
        return HolidayEntry(date: Date(), holiday: chosen)
    }
}

struct HolidayWidgetView: View {
    var entry: HolidayEntry

    var body: some View {
        if !WidgetLook.hasLifetime {
            WidgetLifetimeCard()
        } else if let e = entry.holiday {
            let d = WidgetLook.days(e, from: entry.date)
            VStack(alignment: .leading, spacing: 4) {
                Text(e.name.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(Brand.inkMuted).lineLimit(1)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(d <= 0 ? "Today" : "\(d)").font(Brand.display(44)).foregroundStyle(Brand.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if d > 0 { Text(d == 1 ? "day" : "days").font(.caption).foregroundStyle(Brand.inkMuted) }
                }
                if let total = e.total, total > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(total, 8), id: \.self) { i in
                            Rectangle().fill(i < (e.ready ?? 0) ? Brand.ink : Brand.line).frame(height: 5)
                        }
                    }
                }
                Text(WidgetLook.readiness(e)).font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.inkMuted)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(e.link)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Held Dear").font(Brand.display(22)).foregroundStyle(Brand.ink)
                Text("Turn on a holiday in Held Dear and it counts down here.").font(.caption).foregroundStyle(Brand.inkMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct HolidayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Holiday", intent: PickHoliday.self, provider: HolidayProvider()) { entry in
            HolidayWidgetView(entry: entry)
                .containerBackground(Brand.page, for: .widget)
        }
        .configurationDisplayName("A holiday")
        .description("Days until a holiday you pick, and how ready it is. Part of Held Dear Lifetime.")
        .supportedFamilies([.systemSmall])
    }
}
