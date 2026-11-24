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

