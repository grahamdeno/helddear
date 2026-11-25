# Findings, 1.0 (plan B)

Ratings: 1 cosmetic, 2 minor, 3 hurts use, 4 blocks use. Every 3 and 4 is fixed before the frozen test build.

## From the accessibility review (Nov 24, 2026)

| Item | Area | Status |
|---|---|---|
| UX-1 to UX-9 | Text sizes, contrast, Bold Text, Increase Contrast, shrinking and line limits, gestures with VoiceOver actions, undo time, labels (Stories A to D) | Fixed in PR #122 |
| UX-11 | Small fixed text in widgets now grows with the text size | Fixed in PR #122 |
| UX-13 | Delete all my data | Fixed in PR #122 |
| UX-10 (2) | Reduce Motion honored only on Home; 16 files animate without it | Fixed in PR #122: every animation goes through `Motion`; slides become fades or nothing |
| UX-12 (2) | No "How it works" page | Fixed in PR #122: "How Held Dear works" in You, under Getting started |
| UX-14 (2) | Home has many small text links competing; hard to tell what to tap | Fixed in PR #122: Home now has one button and at most one link under the name (earlier PRs); the "Coming up" header wraps to two rows at large text |

## Store readiness (Nov 24, 2026)

| Item | Status |
|---|---|
| Privacy manifest for the app, widgets and share extension | Added in PR #122 |
| App keeps working with Contacts, Photos, microphone and speech denied | Walk setup `denied` added; result below |

## From the walk (ux-walk.yml)

### Run 45487663525, Nov 24, 2026 (main d1b4d19)

All five setups ran. Apple's audit found 38 issues in light, 37 in dark, 3 at the largest text, 2 on the small phone and
0 in the denied setup. The walk reached Home, a person, Details, You and How it works; its taps missed rows whose
labels carry a value ("iCloud, On"), so People, Ideas, Christmas, iCloud and Export weren't audited. Run 2 fixes the taps
and saves the screenshots for review.

| ID | Rating | Screen | What the audit saw | Next |
|---|---|---|---|---|
| W-1 | 3 until checked | Home | Text clipped on the name, date, subline, status line and link; 4 small hit areas; partial Dynamic Type | Likely Home's shrink-to-fit page and the neighbouring swipe pages; confirm on screenshots, then fix |
| W-2 | 3 until checked | Person, Details | Contrast failed on "1 day · inner ring reminders" and "+ Add to Birthday"; small hit areas on "+ Add to Birthday" and "Not this year" | The brand colours pass (5.4:1 and up), so check the screenshots for scaling or an overlay |
| W-3 | 2 | Home, Details | Dynamic Type partially unsupported on eyebrows, tabs and "+ Add" | Review after W-1 |
| W-4 | Pass | Setup, every permission denied | Setup offers "Add people one at a time instead" with an Add someone button; 0 audit issues | Run 2 walks on into the add form |


### Run 45495068831, Nov 24, 2026 (screenshots on walk-shots/45495068831-*)

The screenshots explain run 1's Home results: in the simulator, Apple's "Sign in to Apple Account" sheet covered Home
(the App Store check at launch), so most of W-1 was the audit reading the sheet. Demo mode now skips the App Store.
The small-phone setup fell back to the iPhone 17 Pro (no iPhone SE simulator on the runner).

| ID | Rating | Screen | Seen in the screenshot | Fix |
|---|---|---|---|---|
| W-1 | Closed | Home | Sign-in sheet over Home in the simulator, not the app | Demo mode skips the App Store check |
| W-5 | 3 | Home, largest text | The line under the name is cut short ("turns 59, in 12 d...") and the first-launch "See Ben" hint sits on top of it | The line wraps at the largest sizes; the hint stays off there |
| W-6 | 3 | Home, largest text | "+ Add Everyo..." cut short under Coming up | A third layout: one link per line |
| W-7 | 3 | Home, largest text | Names on the year line run into each other | The line's names stop growing past xxLarge; VoiceOver still reads each one, and the big name grows without limit |
| W-8 | 2 | You, largest text | The profile card grows very tall and hyphenates "anniversary" | Left as is for 1.0 |
| W-4 | Pass | Setup, every permission denied | "Add people one at a time instead", Add someone, then the alerts step; "Not now" explains the widget and Home | None |
| W-2, W-3 | Re-check in run 3 | Person, Details | The walk opened Home again instead of the person (a name on the line only features that person) | The walk now taps the big name |

### Run 45509595261, Nov 24, 2026 (screenshots on walk-shots/45509595261-*)

W-5, W-6 and W-7 are fixed: at the largest text the line under the name wraps, + Add and Everyone sit one per line, and
the names on the year line no longer collide. The walk still didn't open a person's page (fixed in run 4: it taps
"Ada's page").

| ID | Rating | Screen | Seen in the screenshot | Fix |
|---|---|---|---|---|
| W-9 | 3 | Home, largest text | The page shrinks to fit one screen, so the person's text ends up smaller than chosen and the status line is cut ("You saved 1 idea this...") | At accessibility sizes Home scrolls instead of shrinking; the status line shows in full. Other sizes keep the one-screen Home |
| W-10 | 2 | iCloud page | The back button shows as a blank square in the simulator | Check on a phone |
| W-11 | Test | Setup, denied | The walk stopped at the "Without alerts" note | The walk taps OK and goes on to the add form |

### Run 45519599014, Nov 24, 2026 (screenshots on walk-shots/45519599014-*)

Reached for the first time: Everyone, Finds and the denied add form. Setup with every permission denied now goes all the
way to typing a name (DENIED OK). The small phone (iPhone 17 Pro fallback) had 0 audit issues.

| ID | Rating | Screen | Seen in the screenshot | Fix |
|---|---|---|---|---|
| W-12 | 3 | Everyone, largest text | Dates and "Turns 66" cut short ("Nov 28 ·..."), and the day number broken over two lines | Rows stack at accessibility sizes, with no line limit; the day number gets its full width |
| W-13 | 2 | Home, largest text | Coming up's header takes almost half the screen | The header stops growing at the first accessibility size |
| W-4 | Pass | Setup, denied | Add someone opens the add form and a name can be typed | None |
| W-2, W-3 | Re-check | Person, Details | Not reached: "Ada's page" wasn't tappable in the walk | Run 5 opens the person from Everyone |
