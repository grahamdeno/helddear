import XCTest

/// The accessibility walk (Story E, Nov 24, 2026). Runs the app in demo mode (made-up people, in-memory store), visits
/// the main screens, saves a screenshot of each and runs Apple's accessibility audit on it. Issues are recorded, not
/// failed on: every line printed as `AUDIT|config|screen|type|description` so the run log is the evidence. A screen the
/// walk can't reach is printed as `NOT REACHED|config|screen`, never skipped silently. The config name comes from
/// TEST_RUNNER_WALK_CONFIG (default-light, default-dark, big-text, small-phone).
final class WalkTests: XCTestCase {
    private var app: XCUIApplication!
    private var config: String { ProcessInfo.processInfo.environment["WALK_CONFIG"] ?? "default-light" }
    private var issueCount = 0

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-HeldDearDemo"]
    }

    private func record(_ screen: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(config) · \(screen)"
        shot.lifetime = .keepAlways
        add(shot)
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                self.issueCount += 1
                let element = issue.element.map { "\($0.elementType.rawValue):\($0.label):\(Int($0.frame.minX)),\(Int($0.frame.minY)),\(Int($0.frame.width))x\(Int($0.frame.height))" } ?? "-"
                print("AUDIT|\(self.config)|\(screen)|\(issue.auditType.rawValue)|\(issue.compactDescription)|\(element)")
                return true   // Recorded, not failed: findings go to docs/audit/findings.md.
            }
        } catch {
            print("AUDIT ERROR|\(config)|\(screen)|\(error)")
        }
        print("SCREEN|\(config)|\(screen)")
    }

    /// Taps the first element whose label is this text or starts with it (rows read "iCloud, On"), if it appears within
    /// a few seconds. Scrolls once to look further down the page.
    @discardableResult
    private func tap(_ label: String, screen: String) -> Bool {
        let match = NSPredicate(format: "label == %@ OR label BEGINSWITH %@", label, label + ",")
        for attempt in 0..<4 {
            for query in [app.buttons, app.cells, app.staticTexts, app.otherElements] {
                let el = query.matching(match).firstMatch
                if el.waitForExistence(timeout: attempt == 0 ? 3 : 1) && el.isHittable {
                    el.tap()
                    return true
                }
            }
            app.swipeUp()
        }
        let seen = app.buttons.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty }
        print("NOT REACHED|\(config)|\(screen)|no element labeled \(label)|buttons on screen: \(seen.joined(separator: " / "))")
        return false
    }

    private func back() {
        let b = app.navigationBars.buttons.element(boundBy: 0)
        if b.exists && b.isHittable { b.tap() } else { app.swipeRight() }
        _ = app.wait(for: .runningForeground, timeout: 1)
    }

    func testWalkMainScreens() {
        app.launch()
        record("Home")
        // The ideas page from Home's main button (first-use audit, Nov 25, 2026). The CI simulator has Apple
        // Intelligence, so this is the page with suggestions (V5).
        if tap("See ideas for Ada", screen: "Ideas from Home") { record("Ideas from Home"); back() }

        if tap("Settings", screen: "You and Settings") {
            record("You and Settings")
            if tap("iCloud", screen: "iCloud status") { record("iCloud status"); back() }
            if tap("How Held Dear works", screen: "How it works") { record("How it works"); back() }
            if tap("Export and import", screen: "Export and import") { record("Export and import"); back() }
            back()
        }

        // A name on the line only features that person; the big name then opens the page.
        _ = tap("Ada", screen: "Person")
        // The face and name open the page; VoiceOver calls that button "Ada's page".
        if tap("Ada's page", screen: "Person") {
            record("Person")
            app.swipeUp()
            record("Person, Details")
            if tap("Ideas", screen: "Ideas") { record("Ideas"); back() }
            back()
        }

        if tap("Everyone", screen: "People") {
            record("People")
            // A row in Everyone opens the person's page.
            if tap("Ada", screen: "Person from Everyone") {
                record("Person")
                app.swipeUp()
                record("Person, Details")
                back()
            }
            if tap("Finds", screen: "Finds") { record("Finds") }
            back()
        }

        if tap("Christmas", screen: "Holiday") { record("Holiday"); back() }

        print("WALK DONE|\(config)|issues=\(issueCount)")
    }

    /// An iPhone without Apple Intelligence and without Lifetime, at the free plan limit (Nov 28, 2026). Graham's phone
    /// has both, so these two first-use fixes are checked here: U2, Home offers "Plan Ada's birthday" when there's
    /// nothing to suggest; U4, starting a fourth plan opens Lifetime naming the three people with free plans.
    func testFreeWithoutAppleIntelligence() throws {
        try XCTSkipUnless(config == "free-no-ai", "Runs only in the free-no-ai setup")
        app.launchArguments += ["-HeldDearDemoFreeNoAI"]
        app.launch()
        let plan = app.buttons["Plan Ada's birthday"]
        print("CHECK|\(config)|U2 Home offers Plan Ada's birthday|\(plan.waitForExistence(timeout: 8) ? "pass" : "fail")")
        record("Home, no Apple Intelligence")

        if tap("Everyone", screen: "People") {
            if tap("Elsie", screen: "Elsie's page") {
                record("Elsie's page, plan not started")
                if tap("Gift", screen: "Elsie's gift") {
                    record("Elsie's gift")
                    // "I have an idea" asks how it's coming first; the choice is what moves the gift on.
                    if tap("I have an idea", screen: "How are you getting it"),
                       tap("Buy it in a store", screen: "Elsie's gift, in a store"),
                       tap("Save the plan", screen: "Plan limit") {
                        sleep(2)
                        let line = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@",
                            "Plans for three people are free. Yours are Ben, Cora and Dev.")).firstMatch
                        print("CHECK|\(config)|U4 limit names Ben, Cora and Dev|\(line.waitForExistence(timeout: 5) ? "pass" : "fail")")
                        record("Plan limit")
                    }
                }
            }
        }
        print("WALK DONE|\(config)|issues=\(issueCount)")
    }

    /// Every permission denied (UX audit, Nov 24, 2026). The workflow revokes Contacts, Photos, the microphone and
    /// speech for the app before this runs. Apple expects the app to keep working: setup must offer a way on without
    /// contacts, and a person must be addable by hand.
    func testEverythingDenied() throws {
        try XCTSkipUnless(config == "denied", "Runs only in the denied setup")
        app.launchArguments += ["-HeldDearDemoEmpty"]
        app.launch()
        record("Setup, start")
        if tap("Allow contacts", screen: "Setup, contacts denied") {
            sleep(2)
            record("Setup, contacts denied")
        }
        if tap("Continue", screen: "Add by hand") {
            record("After denied, add someone")
            _ = tap("Not now", screen: "Alerts step")
            let ok = app.alerts.buttons["OK"]
            if ok.waitForExistence(timeout: 3) { ok.tap() }
            sleep(1)
            record("Add by hand")
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 4) {
                field.tap()
                field.typeText("Ada")
                record("Add by hand, name typed")
                print("DENIED OK|\(config)|a person can be added by hand")
            } else {
                print("NOT REACHED|\(config)|Add by hand|no text field")
            }
        }
        print("WALK DONE|\(config)|issues=\(issueCount)")
    }
}
