# Held Dear roadmap

The running plan for Held Dear. It follows Graham's playbook (grahamdeno/playbook, version 1.4.0): the process,
roles, rules and item format live there and aren't repeated here. This file holds what's specific to Held Dear:
where things stand, decisions, the backlog and what shipped.

The plan doc "Held Dear: Product Concept and Plan" (https://claude.ai/artifact/LLoodsJtU3khX5hebKE6ch) stays the
reference for the concept, user journey, data model and screen spec, and holds the full history up to Nov 13, 2026.
From Nov 20, 2026, status, decisions, scope and the backlog live here.

**To pick up the work:** read "Where things stand", then "Decision log", then "Release scope", in that order.

## Project and chats

- **Claude project:** "App | Held Dear".
- **Standing chats:** Held Dear Product (Opus), Held Dear Build (Sonnet), Held Dear Review (Fable), Held Dear Grok.

## Where things stand (Nov 20, 2026)

- **Store:** not released and never submitted. App Store Connect record "Held Dear: Your People" (Apple ID
  6833744147) exists. TestFlight builds 1001 to 1009 uploaded for internal testing. Latest: build 1009, from `main`
  at 34fdc3d (PR #10, Home name follows the timeline), uploaded Nov 14.
- **Branches:** `main` and `testflight` are at the same commit (34fdc3d). PRs #1 to #10 are closed; every one but #4
  was merged (#4's contact picker fix went in with #5). The repo's default branch is `build/v1`, not `main`.
- **Server:** Vercel project helddear-mail is live in production (helddear-mail.vercel.app), last deployed Nov 13.
  Mailed cards run in Handwrytten and Stripe test mode. Family pages store on Vercel Blob and are deleted 30 days
  after the day.
- **Product direction:** "Never stuck on what to give" (decided Nov 13). Phase 1, built in PR #9 and in builds
  1008 and 1009, proves the gift workflow with no new APIs or server setup. Graham is testing it.
- **This file:** created Nov 20, 2026, when Held Dear moved onto playbook 1.4.0. Earlier work was done under the
  repo's own working agreement and isn't counted in docs/sonnet-log.md.
- **Next:** Graham's verdict on the gift workflow in build 1009, then shape the 1.0 release scope (Held Dear Product,
  Opus).

### Open decisions (carried from the plan doc, not yet decided)

- Lifetime in-app purchase: the price is decided ($9.99); the Product ID is not yet approved and the purchase isn't
  created in App Store Connect. The code uses `com.grahamdeno.helddear.lifetime`.
- Mailed card price: $6.99 proposed for the beta, not approved.
- Going live on payments: Stripe live mode and a Handwrytten payment card, at launch.
- Gift workflow phase 2: shop feeds, server search (interests only, never names, with a consent screen) and
  affiliate revenue. Decided only after phase 1 feels right.
- Whether Vercel deploys helddear-mail from `main` on its own (Grok to confirm).

## Product specifics

- **Standing rules:** see CLAUDE.md, "Rules that must never be missed".
- **Core flow (regression list):**
  1. Add people from Contacts, at setup and later from Home.
  2. Heads-up arrives (21 days inner ring, 7 days middle ring, day-of outer ring).
  3. Choose what to do: one plan per screen, including Mail a card.
  4. Gift shelf: share a link to a person, see ideas about six weeks out, pick one, and Home shows when it arrives.
  5. Morning of: the message is ready; pick a photo and send.
  6. Record the year in one line.
  7. Missed: the next morning offers a way back, never a guilt message.
- **Edge cases always checked in Shape:** February 29 (observed February 28), limited Contacts access, a pair on one
  occasion with "Something for each", several occasions in one month, no pronouns, free vs Lifetime, offline (mailed
  cards and family pages need the server).
- **Uploads and deploys:** see CLAUDE.md, "Uploads and deploys in this repo".
- **Guard:** `scripts/privacy_guard.py` keeps data on the phone, allows network only in `MailedCards.swift` and
  `FamilyPages.swift` to helddear-mail.vercel.app, contacts read only, calendar write only.
- **Device checks:** not yet written (`docs/audit/ux-audit.md` comes with the first UX audit).
- **Websites:** none for Held Dear yet; tangomike.app (grahamdeno/tangomike) when it's listed.
- **Compiled-in dates or values:** date rules in `Domain/OccasionDates.swift` (9:00 a.m. alerts, 5-day order-by
  and mail-by, February 29); holiday dates in `Domain/Occasions.swift`; the server host in `MailedCards.swift` and
  `FamilyPages.swift`; the Lifetime Product ID in `Services/Purchases.swift`.

## Steps that can't be undone (this product)

- Deploying helddear-mail to production, and changing its environment variables (Handwrytten, Stripe, Blob keys).
- Turning on Stripe live mode or adding the Handwrytten payment card: real money and real mail.
- Changing the family pages cleanup schedule or rules: it deletes user content.
- The Apple Pay merchant ID and the App Group `group.com.grahamdeno.helddear`.

## Decision log

Newest first. Refined decisions only. Decisions before Nov 13 not repeated here are in the plan doc's Decision log.

| Date | Decision | Why |
|---|---|---|
| Nov 20, 2026 | Held Dear follows playbook 1.4.0. docs/roadmap.md is the running plan; the plan doc stays the concept and spec reference | One process across all of Graham's apps |
| Nov 13, 2026 | Direction: "Never stuck on what to give." A gift shelf filled all year, ideas about six weeks out, pick, buy, and Home shows the arrival. Phase 1 uses no new APIs or server setup | The real problem was not knowing what to give, not forgetting the date |
| Nov 13, 2026 | Graham does not curate a gift collection. Any server gift search later sends interests only, never names, behind a consent screen | Keeps the work and the privacy promise small |
| Nov 12, 2026 | Horizon look: warm stone, one composed page per main screen, Fraunces names, one oxblood action per screen, time left to right | Replaced Hearth, Quiet and the other rejected directions |
| Nov 12, 2026 | Family pages may store what the user and family add on Held Dear's server: no accounts, links that expire, deleted 30 days after the day | Second network exception, enforced by the guard |
| Nov 12, 2026 | Beyond birthdays: anniversaries, holidays and life moments. Hard times are not included | The person is the product, not the birthday |
| Nov 12, 2026 | Held Dear Lifetime: $9.99 one time, no subscription | $19.99 was too high for the audience; costs are near zero on the phone |
| Nov 12, 2026 | Handwrytten mails the cards, paid with Apple Pay through Stripe on Held Dear's server | First network exception; nothing stocked or mailed by Graham |
| Nov 11, 2026 | One-time purchase, no subscription. iPhone only. Data stays on the phone apart from the decided exceptions | Founding decisions |

## Release scope

- **1.0:** not yet planned. Builds 1001 to 1009 are test builds, not a frozen scope.
- **Purchases approved:** Held Dear Lifetime price $9.99 (Nov 12, 2026). Product ID, type and Family Sharing not yet
  approved.
- **Go-aheads under playbook 1.4.0:** none yet.

## Dated checks

- None yet.

## Backlog

Items in the playbook's item format (items.md). Unordered until Graham ranks them. None approved under the playbook
yet.

## Small follow-ups

- Set the repo's default branch to `main` (Grok, needs Graham's go). Not yet approved.
- Clean up merged branches (see the branch list in the onboarding PR). Not yet approved.

## Shipped

- Nothing released. TestFlight builds 1001 to 1009 (Nov 12 to 14, 2026) were for internal testing.
