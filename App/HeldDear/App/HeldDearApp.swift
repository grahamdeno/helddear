import BackgroundTasks
import SwiftUI

@main
struct HeldDearApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    static let refreshTaskID = "com.grahamdeno.helddear.refresh"

    var body: some Scene {
        WindowGroup {
            RootView()
                .overlay(alignment: .bottom) { UndoBanner() }
                .environmentObject(model)
                .onOpenURL { model.openURL($0) }
                .task { await model.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await model.refresh() }
            case .background: Self.scheduleBackgroundRefresh()
            default: break
            }
        }
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            await Self.backgroundRefresh()
        }
    }

    @MainActor
    static func backgroundRefresh() async {
        await AppModel.current?.refresh()
        scheduleBackgroundRefresh()
    }

    /// Keeps the next few weeks of alerts in place even if the app isn't opened for a while.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if StoreSetAside.shouldShow(outcome: model.storeOutcome, acknowledged: model.setAsideAcknowledged) {
                StoreSetAsideView()
            } else if model.onboarded {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .tint(Brand.action)
        .background(Brand.page.ignoresSafeArea())
        // People, holidays and plans are pages that slide in from Home; everything else is a flow in a cover.
        .fullScreenCover(item: Binding(get: { model.route.flatMap { model.navTarget(for: $0) == nil ? $0 : nil } },
                                       set: { model.route = $0 })) { route in
            RouteView(route: route)
                .environmentObject(model)
        }
        .onChange(of: model.route) { old, route in
            if route == nil, case .addBirthday? = old, !model.contactsToDate.isEmpty {
                let next = model.contactsToDate.removeFirst()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if model.route == nil { model.route = .addBirthday("\(next), ") }
                }
                return
            }
            guard let route, let nav = model.navTarget(for: route) else { return }
            model.route = nil
            model.push(nav)
        }
    }
}

/// Every flow opens full screen with one close button, so each screen keeps one decision.
struct RouteView: View {
    @EnvironmentObject var model: AppModel
    let route: Route

    var body: some View {
        switch route {
        case .moment(let id, let step):
            if let m = model.moment(id) {
                MomentFlowView(moment: m, start: step)
            } else {
                Color.clear.onAppear { model.route = nil }
            }
        case .season(let month):
            SeasonView(monthStart: month)
        case .person(let id):
            if let p = model.person(id) {
                NavigationStack { PersonView(person: p).toolbar { CloseToolbar { model.route = nil } }.plainBar() }
            } else {
                Color.clear.onAppear { model.route = nil }
            }
        case .addBirthday(let text):
            AddBirthdayView(initialText: text)
        case .addWish(let personID):
            AddWishView(preselected: personID.flatMap { model.person($0) })
        case .ideas(let id):
            if let m = model.moment(id) { IdeasFlow(moment: m) } else { Color.clear.onAppear { model.route = nil } }
        case .plan(let id):
            if let m = model.moment(id) { PlanView(moment: m) } else { Color.clear.onAppear { model.route = nil } }
        case .holiday(let raw, let year):
            if let ref = HolidayRef(raw: raw) { HolidayView(ref: ref, year: year) } else { Color.clear.onAppear { model.route = nil } }
        case .rings:
            NavigationStack { RingsView().toolbar { CloseToolbar { model.route = nil } }.plainBar() }
        case .lifetime:
            LifetimeView()
        case .settings:
            NavigationStack { SettingsView().toolbar { CloseToolbar { model.route = nil } }.plainBar() }
        }
    }
}

/// "Close" in words at the top left of a screen that slides up, matching the back links (feedback on build 1019).
struct CloseToolbar: ToolbarContent {
    let action: () -> Void
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: action) {
                Text("Close").font(.body).foregroundStyle(Brand.action).fixedSize().frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

extension View {
    /// The plain bar in the page colour that every screen with a bar uses.
    func plainBar() -> some View {
        toolbarBackground(Brand.page, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
    }
}
