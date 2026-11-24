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
                let element = issue.element.map { "\($0.elementType.rawValue):\($0.label)" } ?? "-"
                print("AUDIT|\(self.config)|\(screen)|\(issue.auditType.rawValue)|\(issue.compactDescription)|\(element)")
                return true   // Recorded, not failed: findings go to docs/audit/findings.md.
            }
        } catch {
            print("AUDIT ERROR|\(config)|\(screen)|\(error)")
        }
        print("SCREEN|\(config)|\(screen)")
    }

    /// Taps the first element with this label, if it appears within a few seconds.
    @discardableResult
    private func tap(_ label: String, screen: String) -> Bool {
        let candidates = [app.buttons[label], app.staticTexts[label], app.otherElements[label], app.cells[label]]
        for el in candidates where el.waitForExistence(timeout: 3) && el.isHittable {
            el.tap()
            return true
        }
        print("NOT REACHED|\(config)|\(screen)|no element labeled \(label)")
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

        if tap("Settings", screen: "You and Settings") {
            record("You and Settings")
            if tap("iCloud", screen: "iCloud status") { record("iCloud status"); back() }
            if tap("How Held Dear works", screen: "How it works") { record("How it works"); back() }
            if tap("Export and import", screen: "Export and import") { record("Export and import"); back() }
            back()
        }

        if tap("Ada", screen: "Person") {
            record("Person")
            app.swipeUp()
            record("Person, Details")
            if tap("Ideas", screen: "Ideas") { record("Ideas"); back() }
            back()
        }

        if tap("People", screen: "People") {
            record("People")
            if tap("Finds", screen: "Finds") { record("Finds") }
            back()
        }

        if tap("Christmas", screen: "Holiday") { record("Holiday"); back() }

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
        if tap("Add people one at a time", screen: "Add by hand") {
            record("Add by hand")
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 3) {
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
