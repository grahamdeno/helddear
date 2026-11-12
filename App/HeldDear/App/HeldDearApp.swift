import BackgroundTasks
import SwiftData
import SwiftUI

@main
struct HeldDearApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    static let refreshTaskID = "com.grahamdeno.helddear.refresh"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .modelContainer(model.container)
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
            if model.onboarded {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .tint(Brand.action)
        .background(Brand.page.ignoresSafeArea())
        .fullScreenCover(item: $model.route) { route in
            RouteView(route: route)
                .environmentObject(model)
                .modelContainer(model.container)
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
                NavigationStack { PersonView(person: p).toolbar { CloseToolbar { model.route = nil } } }
            } else {
                Color.clear.onAppear { model.route = nil }
            }
        case .addBirthday(let text):
            AddBirthdayView(initialText: text)
        case .addWish(let personID):
            AddWishView(preselected: personID.flatMap { model.person($0) })
        case .rings:
            NavigationStack { RingsView().toolbar { CloseToolbar { model.route = nil } } }
        case .lifetime:
            LifetimeView()
        case .settings:
            NavigationStack { SettingsView().toolbar { CloseToolbar { model.route = nil } } }
        }
    }
}

struct CloseToolbar: ToolbarContent {
    let action: () -> Void
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: action) { Image(systemName: "xmark") }
                .accessibilityLabel("Close")
        }
    }
}
