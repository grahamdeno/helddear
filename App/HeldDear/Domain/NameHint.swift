import Foundation

/// The light that passes through the name on Home (Graham, Nov 22, 2026): it shows that the name opens the person's
/// page. It plays on the first few launches only, stops for good once a name has been tapped, and never plays with
/// Reduce Motion on. Plain rules, unit tested.
enum NameHint {
    static let maxLaunches = 4
    static let launchesKey = "nameHint.launches"
    static let tappedKey = "nameHint.tapped"
    static let styleKey = "nameHint.style"
    /// Raised when the light changes, so a phone that has already tapped sees the new version once (2: "Stronger").
    static let style = 2

    static func shows(launches: Int, tapped: Bool, reduceMotion: Bool) -> Bool {
        !reduceMotion && !tapped && launches >= 1 && launches <= maxLaunches
    }

    /// Counts this launch once, however many times Home appears.
    private static var counted = false
    static func countLaunch(_ d: UserDefaults = .standard) -> Int {
        if !counted {
            counted = true
            resetForNewStyle(d)
            d.set(d.integer(forKey: launchesKey) + 1, forKey: launchesKey)
        }
        return d.integer(forKey: launchesKey)
    }

    /// A phone that saw an older light starts over: up to four launches, until the next tap.
    static func resetForNewStyle(_ d: UserDefaults = .standard) {
        guard d.integer(forKey: styleKey) != style else { return }
        d.set(style, forKey: styleKey)
        d.set(0, forKey: launchesKey)
        d.set(false, forKey: tappedKey)
    }

    static func tapped(_ d: UserDefaults = .standard) -> Bool { d.bool(forKey: tappedKey) }
    static func markTapped(_ d: UserDefaults = .standard) { d.set(true, forKey: tappedKey) }
}
