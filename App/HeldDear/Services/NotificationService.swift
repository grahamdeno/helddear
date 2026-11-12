import Foundation
import UserNotifications

/// Schedules the planned alerts. Every alert ends with what is ready, never a demand.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    /// Called on the main thread when the user taps a notification or one of its actions.
    var onOpen: ((_ kind: AlertKind?, _ momentID: UUID?, _ monthStart: Date?, _ action: String?) -> Void)?

    func configure() {
        center.delegate = self
        let call = UNNotificationAction(identifier: NotificationCategory.actionCall, title: "Call", options: [.foreground])
        let message = UNNotificationAction(identifier: NotificationCategory.actionMessage, title: "Send a message", options: [.foreground])
        let open = UNNotificationAction(identifier: NotificationCategory.actionOpen, title: "Open", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: NotificationCategory.dayOfCall, actions: [call, message], intentIdentifiers: []),
            UNNotificationCategory(identifier: NotificationCategory.dayOfMessage, actions: [message], intentIdentifiers: []),
            UNNotificationCategory(identifier: NotificationCategory.dayOfOpen, actions: [open], intentIdentifiers: []),
        ])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces every planned alert. One-off alerts (prefix "oneoff-") are kept.
    func replace(with alerts: [PlannedAlert]) async {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { !$0.hasPrefix("oneoff-") }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for alert in alerts {
            try? await center.add(request(for: alert))
        }
    }

    /// "Not yet" on "Did you reach Mom?": ask once more that evening.
    func scheduleEveningCheck(momentID: UUID, name: String, now: Date = Date()) {
        let cal = Calendar.current
        var fire = cal.date(bySettingHour: 19, minute: 0, second: 0, of: now)!
        if fire <= now { fire = now.addingTimeInterval(2 * 60 * 60) }
        let alert = PlannedAlert(id: "oneoff-confirm-\(momentID)", kind: .dayOf, fireDate: fire,
                                 body: "Did you reach \(name)? One tap records it.", momentID: momentID)
        let request = self.request(for: alert, kindOverride: "confirm")
        center.add(request)
    }

    private func request(for alert: PlannedAlert, kindOverride: String? = nil) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = alert.body
        content.sound = .default
        content.threadIdentifier = alert.momentID?.uuidString ?? alert.kind.rawValue
        if let category = alert.category { content.categoryIdentifier = category }
        var info: [String: Any] = ["kind": kindOverride ?? alert.kind.rawValue]
        if let id = alert.momentID { info["moment"] = id.uuidString }
        if let month = alert.monthStart { info["month"] = month.timeIntervalSince1970 }
        content.userInfo = info
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alert.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
    }

    // MARK: Delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let kindRaw = info["kind"] as? String
        let kind = kindRaw == "confirm" ? nil : kindRaw.flatMap(AlertKind.init(rawValue:))
        let moment = (info["moment"] as? String).flatMap(UUID.init(uuidString:))
        let month = (info["month"] as? Double).map(Date.init(timeIntervalSince1970:))
        var action: String? = response.actionIdentifier
        if action == UNNotificationDefaultActionIdentifier { action = nil }
        if kindRaw == "confirm" { action = "confirm" }
        await MainActor.run { self.onOpen?(kind, moment, month, action) }
    }
}
