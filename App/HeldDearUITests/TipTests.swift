import XCTest

/// First-use tips on screen (PR #161, Fable's re-check). Demo people and the in-memory store, but with
/// `-HeldDearDemoTips` so tips show as on a real phone; `-HeldDearDemoTipsReset` marks every tip unseen first. Saves a
/// picture of Home and Ben's page with their tips showing, for the walk.
final class TipTests: XCTestCase {
    private var app: XCUIApplication!
    private var config: String { ProcessInfo.processInfo.environment["WALK_CONFIG"] ?? "tips" }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-HeldDearDemo", "-HeldDearDemoTips", "-HeldDearDemoTipsReset"]
    }

    private func picture(_ screen: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(config) · \(screen)"
        shot.lifetime = .keepAlways
        add(shot)
        print("SCREEN|\(config)|\(screen)")
    }

    private func tip(_ id: String) -> XCUIElement { app.descendants(matching: .any)["tip.\(id)"] }

    private var anyTip: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'tip.'")).firstMatch
    }

    /// The tip's row is one VoiceOver element (line and "Got it" together), so tap where "Got it" sits: beside the
    /// first line, at the trailing end (a 44-point target). The middle of a long tip is its text, not the button.
    private func gotIt(_ el: XCUIElement) {
        el.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: el.frame.width - 22, dy: 22)).tap()
    }

    private func tapLabel(_ label: String) {
        let match = NSPredicate(format: "label == %@ OR label BEGINSWITH %@", label, label + ",")
        for _ in 0..<4 {
            for query in [app.buttons, app.cells, app.staticTexts, app.otherElements] {
                let el = query.matching(match).firstMatch
                if el.waitForExistence(timeout: 2) && el.isHittable { el.tap(); return }
            }
            app.swipeUp()
        }
        XCTFail("No element labeled \(label)")
    }

    func testHomeTipShowsOnceAndStaysGone() {
        app.launch()
        let home = tip("home")
        XCTAssertTrue(home.waitForExistence(timeout: 8), "The Home tip should be on screen on first launch")
        XCTAssertTrue(home.label.contains("The big name is whose day comes next"), "Home tip text: \(home.label)")
        picture("Home, with tip")

        gotIt(home)
        XCTAssertTrue(home.waitForNonExistence(timeout: 3), "The Home tip should go after Got it")

        // Reopen Home: leave for Settings and come back, then quit and relaunch without the reset.
        tapLabel("Settings")
        let b = app.navigationBars.buttons.element(boundBy: 0)
        if b.waitForExistence(timeout: 3) { b.tap() } else { app.swipeRight() }
        XCTAssertFalse(home.waitForExistence(timeout: 2), "The Home tip should stay gone when Home reopens")

        app.terminate()
        app.launchArguments = ["-HeldDearDemo", "-HeldDearDemoTips"]
        app.launch()
        XCTAssertFalse(home.waitForExistence(timeout: 4), "The Home tip should stay gone after a relaunch")
    }

    func testPersonPageShowsOneTipPerVisit() {
        app.launch()
        // Dismiss Home's tip first so it can't be confused with the page's.
        let home = tip("home")
        if home.waitForExistence(timeout: 8) { gotIt(home); _ = home.waitForNonExistence(timeout: 3) }

        tapLabel("Ben")
        tapLabel("Ben's page")
        // Ben has a started plan (demo tips setup), so the plan tip comes first; Ben is also picked for the 3-week
        // heads-up, so the reminders tip is next in line and must wait for another visit.
        let plan = tip("plan")
        for _ in 0..<3 where !plan.exists { app.swipeUp() }
        XCTAssertTrue(plan.waitForExistence(timeout: 6), "The plan tip should show on Ben's page")
        picture("Person, with tip")

        gotIt(plan)
        XCTAssertTrue(plan.waitForNonExistence(timeout: 3), "The plan tip should go after Got it")
        XCTAssertFalse(anyTip.waitForExistence(timeout: 3), "No other tip should appear in the same visit")
    }

    /// The spotlight (Nov 28, 2026): tapping the blurred part of the screen clears the tip and marks it seen, and the
    /// tap doesn't reach what's behind it.
    func testTappingOutsideTheTipClearsIt() {
        app.launch()
        let home = tip("home")
        XCTAssertTrue(home.waitForExistence(timeout: 8), "The Home tip should be on screen on first launch")
        // Bottom of the screen: the timeline, which would open someone's day if the tap got through.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        XCTAssertTrue(home.waitForNonExistence(timeout: 3), "Tapping outside the tip should clear it")
        XCTAssertFalse(app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 2)
                       && app.navigationBars.buttons.element(boundBy: 0).label.hasPrefix("Home"),
                       "The tap outside should not open another page")
        picture("Home, after tapping outside the tip")
        app.terminate()
        app.launchArguments = ["-HeldDearDemo", "-HeldDearDemoTips"]
        app.launch()
        XCTAssertFalse(home.waitForExistence(timeout: 4), "The Home tip should stay gone after a relaunch")
    }

    /// Opens Christmas from Everyone, after clearing Home's tip.
    private func openHoliday() -> XCUIElement {
        let home = tip("home")
        if home.waitForExistence(timeout: 8) { gotIt(home); _ = home.waitForNonExistence(timeout: 3) }
        tapLabel("Everyone")
        tapLabel("Christmas")
        let holiday = tip("holiday")
        XCTAssertTrue(holiday.waitForExistence(timeout: 6), "The holiday tip should show on the holiday page")
        return holiday
    }

    /// A pushed page (Fable, PR #164): the cut-out sits on the tip, so a tap on the tip's words reaches the tip and
    /// doesn't clear it (a misplaced dim would), and "Got it" works.
    func testHolidayPageCutOutSitsOnTheTip() {
        app.launch()
        let holiday = openHoliday()
        picture("Holiday, with tip")
        holiday.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)).tap()
        XCTAssertFalse(holiday.waitForNonExistence(timeout: 2), "A tap on the tip's words should not clear it")
        gotIt(holiday)
        XCTAssertTrue(holiday.waitForNonExistence(timeout: 3), "Got it should clear the holiday tip")
    }

    /// A pushed page has the dim too: a tap well away from the tip clears it.
    func testHolidayPageTapOutsideClearsTheTip() {
        app.launch()
        let holiday = openHoliday()
        // Just under the tip, on the summary text: nothing there to tap, so only the dim can clear the tip (a tap that
        // reached a button would leave the page and hide the tip for the wrong reason).
        let below = holiday.frame.maxY + 40
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: holiday.frame.midX, dy: below)).tap()
        XCTAssertTrue(holiday.waitForNonExistence(timeout: 3), "A tap on the dim should clear the holiday tip")
        XCTAssertTrue(app.staticTexts["Christmas"].exists, "The tap on the dim should leave the holiday page open")
    }
}
