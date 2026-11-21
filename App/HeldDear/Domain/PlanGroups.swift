import Foundation

/// A day's plan grouped by what each thing is, so it reads at a glance (approved Nov 20, 2026): Gifts, The day,
/// Little touches. The app sorts every kind into its group; the user never sorts anything.
enum PlanGroup: CaseIterable, Equatable {
    case gifts, theDay, touches

    var title: String {
        switch self {
        case .gifts: "Gifts"
        case .theDay: "The day"
        case .touches: "Little touches"
        }
    }

    /// By kind; something typed in ("Gift from Ben") goes by its name when its kind doesn't say.
    static func group(forKindRaw raw: String, name: String = "") -> PlanGroup {
        switch ActKind(rawValue: raw) {
        case .gift, .stocking, .fromSanta, .kidsMade: return .gifts
        case .cake, .dinner, .theDay: return .theDay
        case .card, .flowers, .call, .message: return .touches
        default:
            let n = name.lowercased()
            if n.contains("gift") || n.contains("present") || n.contains("stocking") { return .gifts }
            if n.contains("dinner") || n.contains("breakfast") || n.contains("party") || n.contains("cake") { return .theDay }
            return .touches
        }
    }

    /// "2 of 3 ready", or "All ready".
    static func summary(ready: Int, total: Int) -> String {
        total > 0 && ready == total ? "All ready" : "\(ready) of \(total) ready"
    }

    /// The count line over the groups: "5 to decide · 3 on the way · 1 ready", leaving out any that are zero.
    static func countLine(toDecide: Int, onTheWay: Int, ready: Int) -> String {
        var bits: [String] = []
        if toDecide > 0 { bits.append("\(toDecide) to decide") }
        if onTheWay > 0 { bits.append("\(onTheWay) on the way") }
        if ready > 0 { bits.append("\(ready) ready") }
        return bits.joined(separator: " · ")
    }
}
