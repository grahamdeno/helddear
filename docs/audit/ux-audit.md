# UX and accessibility audit, 1.0 (plan B)

Started Nov 24, 2026. Playbook 1.4.0, Stage 5.

## How the walk runs

- `ux-walk.yml`, run by hand. Uploads nothing and changes nothing live.
- The app opens in demo mode (`-HeldDearDemo`, debug builds only): eight made-up people in an in-memory store. No real
  data, no iCloud, no notification prompt.
- `WalkTests.testWalkMainScreens` visits Home, Settings, iCloud status, Your data, a person, the person's details and
  ideas, People, Finds and a holiday. Each screen gets a screenshot and Apple's accessibility audit
  (`performAccessibilityAudit`, all checks).
- Four setups: default light, default dark, the largest accessibility text size, and the small phone (iPhone SE).
- Issues are recorded, not failed on. The log prints one `AUDIT|setup|screen|type|issue|element` line per issue and
  `NOT REACHED|setup|screen` for any screen the walk couldn't open, so nothing is skipped silently.
- Screenshots stay in the run's artifacts for 30 days.

## After a run

1. Copy each `AUDIT` line into findings.md with a rating (1 cosmetic, 2 minor, 3 hurts use, 4 blocks use).
2. Fix every 3 and 4 before the frozen test build (playbook Stage 5).
3. Opus rates the screenshots for clipping, overlap and contrast the audit can't see.
