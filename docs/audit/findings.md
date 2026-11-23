# Held Dear UX audit findings

<!-- One section per run. IDs are never reused. Started from the playbook's templates/findings.md. -->

Severity: 4 blocks a job, loses data or locks people out; 3 people will stumble; 2 slows or confuses; 1 cosmetic;
0 not a problem on reflection. 4 and 3 are fixed before release unless Graham accepts a 3 in writing below.

## Run 1: 4619e1a (Nov 23, 2026), code review by Fable, no walk yet; configs and journeys as in [ux-audit.md](ux-audit.md)

| # | Sev | Where | What a person sees | Fix | Status |
|---|---|---|---|---|---|
| UX-1 | 3 | All screens; Brand.swift:101-102 (about 130 uses) | Captions at 13 pt and eyebrows at 12 pt in muted ink are hard to read, especially outdoors or with weaker eyes | Caption 15 pt, eyebrow 13 pt, both in soft ink | Open |
| UX-2 | 3 | Home Screen widgets; HomeWidgets.swift:116-276, NextPersonWidget.swift:90-104 | Widget text is 10 to 11 pt and doesn't grow with the system text size | Text styles that grow with the system, smallest 13 pt; let lines wrap | Open |
| UX-3 | 3 | Headings and names; Brand.swift:52-58, :108 | With Bold Text on, names and headings stay thin and light | Use a heavier Fraunces weight when Bold Text is on | Open |
| UX-4 | 3 | Lists with swipe-to-remove; SwipeToRemove.swift:28-63 | VoiceOver users can't remove anything; removal is swipe only | Add a "Remove" accessibility action on each row | Open |
| UX-5 | 3 | Focus picker and suggestions; PersonView.swift:1567-1618, BirthdaySuggestions.swift:229-232 | Centering a photo needs drag, pinch or double-tap; nothing works with VoiceOver or Switch Control | Adjustable actions: move left, right, up, down; closer, wider | Open |
| UX-6 | 3 | PersonPlanSection.swift:124-129, :243; RingsView.swift:76-108; PlanView.swift:805, :1013; FindsView.swift:66, :97 | Names, notes, statuses and dates cut off with "…" at larger text | Allow 2 lines or no limit; rows grow | Open |
| UX-7 | 3 | Borders and dividers; Brand.swift:15, :19 | Lines between rows are nearly invisible (1.2 to 1.4:1), and Increase Contrast changes nothing | Lines at least 3:1; darker lines and soft ink with Increase Contrast | Open |
| UX-8 | 3 | Undo banner; SwipeToRemove.swift:75-93 | The Undo banner disappears quickly, and VoiceOver doesn't say it appeared | Announce it; keep it 8 seconds, longer with VoiceOver on | Open |
| UX-9 | 3 | Home; HomeView.swift:20-25, :936-947 | Settings is a circle with an initial; nothing says it's Settings | VoiceOver label "Settings"; a visible hint on first run | Open |
| UX-10 | 2 | 16 files outside Home | Animations play with Reduce Motion on | Honor Reduce Motion everywhere (fade or none) | Open |
| UX-11 | 2 | HolidayView.swift:70, PlanView.swift:101, HomeView.swift:850, :873 | Long names and titles shrink to half size instead of wrapping | Smallest scale 0.8; wrap instead | Open |
| UX-12 | 2 | Whole app | No page explains how Held Dear works | Add a short "How it works" page from You | Open |
| UX-13 | 2 | You / Settings | No way to delete all my data from the app | Add "Delete all my data" with a confirmation, including iCloud | Open |
| UX-14 | 2 | Home; HomeView.swift:312-404, :463-477 | Many small text links compete; hard to tell what to tap | Cut to the main action plus a few links; the rest moves to the person or the You page | Open |

**Test-side, not the app:** none yet.

**Known false alarms:** none yet.

**People:** none yet.
