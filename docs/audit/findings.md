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

Not run yet. Each run's `AUDIT` and `NOT REACHED` lines go here with the setup, screen, rating and fix.
