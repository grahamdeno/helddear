import XCTest

/// The UX walk (Story E, playbook standards/ux-audit.md). It runs the journeys in demo mode (`-HeldDearDemo`: made-up
/// people, a fixed date, an in-memory store) in one of four configs, chosen by the WALK_CONFIG environment variable.
///
/// A step that can't be found is written down and the walk goes on; it does not stop the walk. The only failure is
/// the app not running (a crash). Everything else is evidence: a screenshot per step, the visible labels where a step
/// was missed, and Apple's accessibility audit per main screen. Opus reads these and rates the findings.
struct WalkConfig {
    let name: String
    let dark: Bool
    /// Launch value for the system text size, nil for the default.
    let textSize: String?
    let journeys: ClosedRange<Int>

    static let all: [String: WalkConfig] = [
        "default-light": WalkConfig(name: "default-light", dark: false, textSize: nil, journeys: 1...12),
        "default-dark": WalkConfig(name: "default-dark", dark: true, textSize: nil, journeys: 1...7),
        "big-text": WalkConfig(name: "big-text", dark: false, textSize: "UICTContentSizeCategoryAccessibilityXXXL", journeys: 1...7),
        "small-phone": WalkConfig(name: "small-phone", dark: false, textSize: nil, journeys: 1...7),
    ]

    static var current: WalkConfig {
        all[ProcessInfo.processInfo.environment["WALK_CONFIG"] ?? "default-light"] ?? all["default-light"]!
    }
}

/// A main screen and the labels to tap, in order, from Home to reach it.
struct WalkScreen {
    let name: String
    let path: [String]
}

final class WalkTests: XCTestCase {
    private let config = WalkConfig.current
    private var app: XCUIApplication!
    private var lines: [String] = []
    private var shotCount = 0

    /// Every main screen that gets Apple's accessibility audit, in every config. The paths are the walk's best reading
    /// of the screens; a path that fails is reported with the labels on screen so the path can be corrected.
    static let screens: [WalkScreen] = [
        WalkScreen(name: "Home", path: []),
        WalkScreen(name: "People", path: ["Everyone"]),
        WalkScreen(name: "Person (top)", path: ["'s page"]),
        WalkScreen(name: "Person (Details)", path: ["'s page", "Details"]),
        WalkScreen(name: "Plan for a day", path: ["Plan"]),
        WalkScreen(name: "Add a day (When is it?)", path: ["'s page", "Add a day"]),
        WalkScreen(name: "Married to picker", path: ["'s page", "Add a day", "Anniversary", "Married to"]),
        WalkScreen(name: "Ideas", path: ["Ideas"]),
        WalkScreen(name: "Finds", path: ["Finds"]),
        WalkScreen(name: "Holiday page (Christmas)", path: ["Christmas"]),
        WalkScreen(name: "Focus picker", path: ["'s page", "Photo", "Focus"]),
        WalkScreen(name: "Share day", path: ["Share"]),
        WalkScreen(name: "Make a digital card", path: ["Make a card"]),
        WalkScreen(name: "You / Settings", path: ["You and settings"]),
    ]

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.appearance = config.dark ? .dark : .light
        lines = ["CONFIG \(config.name)"]
    }

    override func tearDown() {
        let text = XCTAttachment(string: lines.joined(separator: "\n"))
        text.name = "walk-\(config.name)-\(name.replacingOccurrences(of: " ", with: "_"))"
        text.lifetime = .keepAlways
        add(text)
    }

    // MARK: The screens

    func testScreens_everyMainScreenIsAudited() {
        for screen in Self.screens {
            launch(people: 4)
            let reached = follow(screen.path)
            if reached {
                shot("screen-\(screen.name)")
                audit(screen.name)
            } else {
                log("SCREEN | \(screen.name) | NOT REACHED | on screen: \(visibleLabels())")
                shot("screen-\(screen.name)-not-reached")
            }
            assertRunning()
        }
    }

    // MARK: The journeys

    /// 1. First run: launch, add 3 people, then Home.
    func testJ01_firstRun() throws {
        try XCTSkipUnless(config.journeys.contains(1))
        launch(people: 0)
        shot("j1-launch")
        log("J1 | launch | on screen: \(visibleLabels())")
        _ = tap("Not now") || tap("Add people one at a time")
        for (i, name) in ["Robin", "Jordan", "Casey"].enumerated() {
            let added = addPersonTyped("\(name), March \(3 + i)")
            log("J1 | add \(name) | \(added ? "done" : "MISSED, on screen: \(visibleLabels())")")
            shot("j1-added-\(name)")
        }
        let people = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "'s page")).count
        log("J1 | Home shows \(people) people pages (pass: 3, no dead end)")
        shot("j1-home")
        assertRunning()
    }

    /// 2. Core loop: plan a card part and mark it done, for 3 people.
    func testJ02_coreLoop() throws {
        try XCTSkipUnless(config.journeys.contains(2))
        launch(people: 4)
        for i in 1...3 {
            let steps = ["Plan", "Card", "I'll get one myself", "Done"]
            var reached = 0
            for s in steps { if tap(s) { reached += 1 } else { break } }
            log("J2 | person \(i) | reached \(reached) of \(steps.count) steps | on screen: \(reached < steps.count ? visibleLabels() : "")")
            shot("j2-person-\(i)")
            _ = tap("Close") || tap("Back")
        }
        assertRunning()
    }

    /// 3. Remove and Undo: swipe-remove a People row, then Undo.
    func testJ03_removeAndUndo() throws {
        try XCTSkipUnless(config.journeys.contains(3))
        launch(people: 4)
        guard tap("Everyone") else { log("J3 | People | NOT REACHED | on screen: \(visibleLabels())"); return }
        let rows = app.cells
        let before = rows.count
        if before > 0 {
            rows.firstMatch.swipeLeft()
            shot("j3-swiped")
            let removed = tap("Remove") || tap("Delete")
            shot("j3-removed")
            let undone = tap("Undo")
            log("J3 | People row | rows before \(before), removed \(removed), undo \(undone), rows after \(app.cells.count)")
        } else {
            log("J3 | People row | no rows found, on screen: \(visibleLabels())")
        }
        log("J3 | photo Remove and Add something Remove | NOT WALKED: the demo people have no photos or items")
        assertRunning()
    }

    /// 4. Create: add a person, add an anniversary, save an idea.
    func testJ04_create() throws {
        try XCTSkipUnless(config.journeys.contains(4))
        launch(people: 4)
        let added = tap("Add") && addPersonTyped("Sky, June 9")
        log("J4 | add a person | \(added ? "done" : "MISSED, on screen: \(visibleLabels())")")
        launch(people: 4)
        let steps = ["'s page", "Add a day", "Anniversary", "Married to"]
        var reached = 0
        for s in steps { if tap(s) { reached += 1 } else { break } }
        log("J4 | anniversary | reached \(reached) of \(steps.count) | on screen: \(visibleLabels())")
        shot("j4-anniversary")
        launch(people: 4)
        let idea = tap("Ideas")
        log("J4 | Ideas | \(idea ? "opened" : "MISSED, on screen: \(visibleLabels())")")
        shot("j4-ideas")
        assertRunning()
    }

    /// 5. Find again: the 40th person, Finds filters, a person's Ideas.
    func testJ05_findAgain() throws {
        try XCTSkipUnless(config.journeys.contains(5))
        launch(people: 60)
        guard tap("Everyone") else { log("J5 | People | NOT REACHED | on screen: \(visibleLabels())"); return }
        let target = "Avery C"   // the 40th made-up person (see DemoMode.name(at:))
        var found = find(target).exists
        var swipes = 0
        while !found && swipes < 30 { app.swipeUp(); swipes += 1; found = find(target).exists }
        log("J5 | 40th person \(target) | found \(found) after \(swipes) swipes")
        if found { find(target).tap() }
        shot("j5-40th")
        launch(people: 4)
        let finds = tap("Finds")
        log("J5 | Finds | \(finds ? "opened" : "MISSED, on screen: \(visibleLabels())")")
        if finds { _ = tap("Partner"); shot("j5-finds-partner") }
        assertRunning()
    }

    /// 6. Settings: every row opens and comes back.
    func testJ06_settingsRows() throws {
        try XCTSkipUnless(config.journeys.contains(6))
        launch(people: 4)
        guard tap("You and settings") else { log("J6 | Settings | NOT REACHED | on screen: \(visibleLabels())"); return }
        let skip: Set<String> = ["Close", "Done", ""]
        let rows = app.buttons.allElementsBoundByIndex.prefix(30).map(\.label).filter { !skip.contains($0) }
        log("J6 | rows found: \(rows.joined(separator: " / "))")
        for row in rows.prefix(12) {
            guard tap(row) else { log("J6 | \(row) | could not tap"); continue }
            shot("j6-\(row)")
            _ = tap("Close") || tap("Back") || tap("Done") || tap("Not now") || goBackFromBar()
            let back = find("Close").exists || find("Export my data").exists
            log("J6 | \(row) | opened, came back \(back)")
        }
        assertRunning()
    }

    /// 7. Empty states.
    func testJ07_emptyStates() throws {
        try XCTSkipUnless(config.journeys.contains(7))
        launch(people: 4)
        let steps = [["'s page", "Ideas"], ["Finds"]]
        for path in steps {
            launch(people: 4)
            let ok = follow(path)
            log("J7 | \(path.joined(separator: " > ")) | \(ok ? "opened" : "MISSED") | on screen: \(visibleLabels())")
            shot("j7-\(path.last ?? "")")
        }
        assertRunning()
    }

    /// 8. Heavy and odd data: 300 people and odd names, fast scrolling.
    func testJ08_heavyAndOddData() throws {
        try XCTSkipUnless(config.journeys.contains(8))
        launch(people: 300, extra: ["-demoOdd"])
        shot("j8-home")
        audit("Home (heavy data)")
        if tap("Everyone") {
            for _ in 0..<10 { app.swipeUp(velocity: .fast) }
            shot("j8-people-scrolled")
            for _ in 0..<10 { app.swipeDown(velocity: .fast) }
        }
        log("J8 | scroll | app still running: \(app.state == .runningForeground)")
        assertRunning()
    }

    /// 9. Paid path: Plan, Send a card, Mail a handwritten card.
    func testJ09_paidPath() throws {
        try XCTSkipUnless(config.journeys.contains(9))
        launch(people: 4)
        let steps = ["Plan", "Send a card", "Mail a handwritten card"]
        var reached = 0
        for s in steps { if tap(s) { reached += 1 } else { break } }
        log("J9 | reached \(reached) of \(steps.count) | on screen: \(visibleLabels())")
        shot("j9-end")
        assertRunning()
    }

    /// 10. Away two weeks: day 0, then 14 days on.
    func testJ10_awayTwoWeeks() throws {
        try XCTSkipUnless(config.journeys.contains(10))
        launch(people: 4, days: 0)
        shot("j10-day-0")
        log("J10 | day 0 | on screen: \(visibleLabels())")
        launch(people: 4, days: 14)
        shot("j10-day-14")
        let labels = visibleLabels()
        let guilt = ["forgot", "overdue", "streak", "you missed"].filter { labels.lowercased().contains($0) }
        log("J10 | day 14 | guilt words found: \(guilt.isEmpty ? "none" : guilt.joined(separator: ", ")) | on screen: \(labels)")
        audit("Home (14 days on)")
        assertRunning()
    }

    /// 11. How it works: expected to fail today (UX-12). Recorded.
    func testJ11_howItWorks() throws {
        try XCTSkipUnless(config.journeys.contains(11))
        launch(people: 4)
        _ = tap("You and settings")
        let found = find("How it works").exists || find("Help").exists
        log("J11 | help page | \(found ? "FOUND (UX-12 may be fixed)" : "not found, as expected today (UX-12)")")
        shot("j11-you")
    }

    /// 12. Refused or offline: the You page iCloud row. The family page with the network off is not walked here.
    func testJ12_refusedOrOffline() throws {
        try XCTSkipUnless(config.journeys.contains(12))
        launch(people: 4)
        _ = tap("You and settings")
        let icloud = find("iCloud").exists
        log("J12 | You page iCloud row | \(icloud ? "present" : "not found") | on screen: \(visibleLabels())")
        shot("j12-you")
        log("J12 | family page with the network off | NOT WALKED: the walk can't switch the network off")
    }

    // MARK: Helpers

    private func launch(people: Int, days: Int = 0, extra: [String] = []) {
        if app != nil { app.terminate() }
        app = XCUIApplication()
        var args = ["-HeldDearDemo", "-demoDate", "2026-12-10", "-demoDays", "\(days)", "-demoPeople", "\(people)",
                    "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if let size = config.textSize { args += ["-UIPreferredContentSizeCategoryName", size] }
        app.launchArguments = args + extra
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
        settle()
    }

    private func settle(_ seconds: TimeInterval = 0.7) { Thread.sleep(forTimeInterval: seconds) }

    private func assertRunning(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.state, .runningForeground, "The app is not running (a crash?) at: \(lines.last ?? "")", file: file, line: line)
    }

    private func log(_ line: String) { lines.append(line) }

    /// An element whose label is the text, or contains it. Buttons and cells first.
    private func find(_ text: String) -> XCUIElement {
        let exact = NSPredicate(format: "label ==[c] %@", text)
        let part = NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", text, text)
        for query in [app.buttons, app.cells, app.staticTexts, app.otherElements] {
            let e = query.matching(exact).firstMatch
            if e.exists { return e }
        }
        for query in [app.buttons, app.cells, app.staticTexts, app.otherElements] {
            let e = query.matching(part).firstMatch
            if e.exists { return e }
        }
        return app.buttons[text]
    }

    /// Waits up to `timeout` seconds for the text, taps it, and lets the screen settle.
    @discardableResult
    private func tap(_ text: String, timeout: TimeInterval = 4) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            let e = find(text)
            if e.exists && e.isHittable { e.tap(); settle(); return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    private func follow(_ path: [String]) -> Bool {
        for label in path where !tap(label) { return false }
        return true
    }

    private func goBackFromBar() -> Bool {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        guard back.exists else { return false }
        back.tap(); settle(); return true
    }

    /// Types "Name, March 3" into the first field of whatever add screen is open, then confirms.
    private func addPersonTyped(_ text: String) -> Bool {
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 4) else { return false }
        field.tap()
        field.typeText(text)
        return tap("Save") || tap("Add") || tap("Done") || tap("Next") || tap("Continue")
    }

    /// The labels of what is on screen: buttons, then text, for a missed step.
    private func visibleLabels() -> String {
        let buttons = app.buttons.allElementsBoundByIndex.prefix(25).map(\.label)
        let texts = app.staticTexts.allElementsBoundByIndex.prefix(25).map(\.label)
        let all = (buttons + texts).filter { !$0.isEmpty }
        return all.prefix(40).joined(separator: " / ")
    }

    private func shot(_ name: String) {
        shotCount += 1
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = String(format: "%@-%02d-%@", config.name, shotCount, name)
        a.lifetime = .keepAlways
        add(a)
    }

    /// Apple's accessibility audit on the screen now. Issues are recorded, not failed: they are findings.
    private func audit(_ screen: String) {
        var issues: [String] = []
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                issues.append("\(issue.auditType.rawValue): \(issue.compactDescription) [\(issue.element?.label ?? "")]")
                return true
            }
        } catch {
            issues.append("the audit itself failed: \(error)")
        }
        log("AUDIT | \(screen) | \(issues.count) issue(s)")
        for issue in issues { log("AUDIT |   \(issue)") }
    }
}
