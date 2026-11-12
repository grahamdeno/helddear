import CallKit
import EventKit
import UIKit

/// Places a call and notices whether an outgoing call connected right after.
/// Apple shows the app that a call connected, never who was called; a connection soon after
/// the app started a call counts as done. Otherwise the app asks one question.
final class CallService: NSObject, CXCallObserverDelegate {
    static let shared = CallService()
    private let observer = CXCallObserver()
    private(set) var pendingStart: Date?
    private(set) var sawConnection = false
    /// Called on the main thread when a call started by the app connects.
    var onConnected: (() -> Void)?

    override init() {
        super.init()
        observer.setDelegate(self, queue: .main)
    }

    @MainActor
    func call(_ number: String) -> Bool {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)"), UIApplication.shared.canOpenURL(url) else { return false }
        pendingStart = Date()
        sawConnection = false
        UIApplication.shared.open(url)
        return true
    }

    /// The call the app started either connected or the user came back without one.
    func resolve() { pendingStart = nil; sawConnection = false }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        guard let start = pendingStart, call.isOutgoing, call.hasConnected,
              Date().timeIntervalSince(start) < 10 * 60 else { return }
        if !sawConnection {
            sawConnection = true
            onConnected?()
        }
    }
}

/// Adds a dinner date the user chose. Write-only access: the app never reads the calendar.
enum CalendarService {
    static func addDinner(title: String, on date: Date) async -> Bool {
        let store = EKEventStore()
        guard (try? await store.requestWriteOnlyAccessToEvents()) == true else { return false }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = date
        event.endDate = date.addingTimeInterval(2 * 60 * 60)
        event.calendar = store.defaultCalendarForNewEvents
        do { try store.save(event, span: .thisEvent); return true } catch { return false }
    }
}
