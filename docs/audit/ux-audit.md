# Held Dear UX audit: journeys, configs and demo mode

Follows the playbook's `standards/ux-audit.md` (1.4.0). The findings are in [findings.md](findings.md).

## How the walk runs

- **Where:** the `ux-walk` job in `.github/workflows/build.yml`. It runs when started by hand (Actions > build > Run
  workflow) or on a pull request from a branch named `test/ux-*`. It costs Mac minutes, so it does not run on every PR.
- **What:** the `HeldDearWalk` scheme runs the UI tests in `App/HeldDearUITests/WalkTests.swift` once per config.
  The job builds once, then runs the four configs below.
- **Result:** a CI artifact named `helddear-ux-walk-<run>-<attempt>` with `results.md` (every step, every miss and
  Apple's accessibility audit per screen), one folder of screenshots per config, and the logs.
- **A step that can't be found is written down and the walk goes on.** The walk fails only when the app stops running.
  A missed step lists the labels on screen, so the path in `WalkTests.swift` can be corrected.

## Demo mode

Debug builds only, and only with the launch argument `-HeldDearDemo` (`App/HeldDear/App/DemoMode.swift`). A release
build never has it.

| Argument | What it does |
|---|---|
| `-HeldDearDemo` | Turns demo mode on: made-up people in an in-memory store |
| `-demoDate 2026-12-10` | The fixed date for the model rules (default Dec 10, 2026) |
| `-demoDays N` | Moves that date N days on (journey 10) |
| `-demoPeople N` | How many made-up people (default 4; 0 starts at the first-run screens; 300 for heavy data) |
| `-demoOdd` | Adds a 57-letter name and Arabic, Japanese and emoji names |

In demo mode the app never reads or writes the real store, iCloud, Contacts, Photos or notifications, and never writes
widget or Lock Screen data. Names are invented; the privacy guard checks the code for real family names.

**Known limit:** the model rules take the demo date, but about 94 lines in 36 files read the real clock (`Date()`)
directly, mostly in screens. Until those read one shared clock, a few screen texts follow the real date. The walk's
Home and Person pictures should be read with that in mind.

## Configs

| Config | Device | Look | Text | Journeys |
|---|---|---|---|---|
| default-light | iPhone 17 Pro | Light | Default | All, with time replay |
| default-dark | iPhone 17 Pro | Dark | Default | 1 to 7 |
| big-text | iPhone 17 Pro | Light | Accessibility XXXL | 1 to 7 |
| small-phone | iPhone SE (3rd gen) | Light | Default | 1 to 7 |

Every config also runs Apple's `performAccessibilityAudit()` on every main screen.

## Journeys

| # | Journey | Person | Steps | Pass condition | Target cost |
|---|---|---|---|---|---|
| 1 | First run | New user | Launch, then add 3 people from the demo contacts, then Home | Home shows the 3 in the band; no dead end | 6 |
| 2 | Core loop | Planner | Home, next person, Plan, add a card part ("I'll get one myself"), mark done; repeat for 3 people | Each day shows as planned or done | 5 each |
| 3 | Remove and Undo | Anyone | Swipe-remove a People row, Undo; Person > photo > Remove from this person, Undo; Add something > remove an item, Undo | Each comes back after Undo | 3 each |
| 4 | Create | Planner | Add a person; Add a day > Anniversary > Married to (pick a person) > Save; Ideas > Save an idea | Anniversary shows on both pages; idea is saved | 12 total |
| 5 | Find again | Anyone | People: scroll and open the 40th person; Finds: Partner filter plus price; a person's Ideas | The right person and finds show | 4 |
| 6 | Settings | Anyone | Home > Settings circle > every row opens and comes back | Every row returns | 2 per row |
| 7 | Empty states | New user | A person with no photos, ideas or loves; Finds filtered to nothing | Each says what to do next | 0 |
| 8 | Heavy and odd data | Power user | 300 people; a 57-letter name; Arabic, Japanese and emoji names; no photos; a paragraph-long note; scroll Home and People fast | No crash, no broken words, no sideways scroll | n/a |
| 9 | Paid path | Card sender | Plan > Send a card > Mail a handwritten card | Reaches the card picker or a plain "not available here" (demo has no network), never a dead end | 3 |
| 10 | Away two weeks | Lapsed user | `-demoDays 0`, then 14 | Home shows a missed day with a way back; no guilt words | 0 |
| 11 | How it works | New user | Look for help | Expected to fail today (UX-12); record it | n/a |
| 12 | Refused or offline | Anyone | You page iCloud row with sync not ready; make a family page with the network off | A plain message says what's wrong and what to do | 1 |

## Main screens (Apple's audit runs on each, in every config)

Home; People; Person (top and Details, including Coming up from Held Dear); Plan for a day; Add a day ("When is it?");
Married to picker; Ideas; Finds; Holiday page (Christmas, with Traditions); Focus picker; Share day; Make a digital
card; You / Settings.

## Not walked by the simulator (these go to phone checks)

Notifications arriving, Live Activities, widgets, the share extension, real Apple Pay, iCloud sync, the Contacts
write-back prompt, link previews, the mailed-card catalog and family pages (both need the network).

Also not walked yet, because demo mode has no photos or items: the photo "Remove from this person" and Add something
"remove an item" parts of journey 3, and the family page with the network off in journey 12.
