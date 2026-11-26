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

## Where things stand (Nov 24, 2026)

- **Store:** not released and never submitted. App Store Connect record "Held Dear: Your People" (Apple ID
  6833744147). Latest TestFlight build: **1053**, from `main` at 4e24a2f, uploaded Nov 24 (first build with working
  iCloud sync). Install by updating over the existing app; never delete it first.
- **Branches:** the default branch is `main` (changed from `build/v1` on Nov 23, 2026). `testflight` is at 4e24a2f.
- **iCloud (done Nov 24, 2026):** the CloudKit schema (`cloudkit/schema.ckdb`, generated from model 3.3: 7 record
  types, encrypted fields, an asset companion for every text and binary field) was proven in the test container by
  the Schema Test app (all 14 records uploaded in Production), passed by Fable, imported to the real Development and
  **deployed to the real Production** (Grok, on Graham's go; only additions). Build 1053 sends and receives on
  Graham's iPhone, his data is in iCloud, and his iPad picks it up. Signed builds use Production; the app never
  creates record types itself. Requirement R2 (sharing tested in the test container first) is under Small follow-ups.
- **Schema Test app:** target `HeldDearSchemaTest`, bundle `com.grahamdeno.helddear.schematest`, container
  `iCloud.com.grahamdeno.helddear.schematest`, group `group.com.grahamdeno.helddear.schematest`, App Store Connect
  record "Held Dear Schema Test" (Apple ID 6838458371, internal only, never submitted). Never part of the real app.
  Workflows `schematest-testflight.yml`, `cloudkit-schema-test.yml` and `cloudkit-schema.yml` run by hand on
  Graham's go; all are Development-only for schemas.
- **Server:** Vercel project helddear-mail is live in production (helddear-mail.vercel.app), last deployed Nov 13.
  Mailed cards run in Handwrytten and Stripe test mode. Family pages store on Vercel Blob and are deleted 30 days
  after the day.
- **Product direction:** "Never stuck on what to give" (decided Nov 13). Phase 1, built in PR #9 and in builds
  1008 and 1009, proves the gift workflow with no new APIs or server setup. Graham is testing it.
- **This file:** created Nov 20, 2026, when Held Dear moved onto playbook 1.4.0. Earlier work was done under the
  repo's own working agreement and isn't counted in docs/sonnet-log.md.
- **1.0 scope:** planned Nov 20 after Fable's strategy review (Go). Core job: plan the whole occasion. See
  "Release scope" and Epics 1 and 2.
- **Christmas hand test** runs Nov 21 to Dec 26 on paper (see "Dated checks").
- **Next:** words and Horizon mockups for the occasion plan (Epic 2, S1 to S4), then the holiday page (Epic 1)
  (Held Dear Product, Opus).

### Open decisions (carried from the plan doc, not yet decided)

- Mailed card price: $6.99 proposed, not approved. Mailed cards are off in 1.0.
- Going live on payments (Stripe live mode, a Handwrytten payment card), server rate limits and the Fable security
  review: needed before mailed cards or family pages are turned on in a later update.
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
| Nov 20, 2026 | Core job for 1.0: plan the whole occasion. Each occasion has parts, each part an owner, a status and a date. The gift shelf feeds the Gift part | Fable's strategy review (Go) and Graham's own paper plan |
| Nov 20, 2026 | Free: reminders, morning-of message and yearly line for everyone; plans for 3 people. Lifetime unlocks plans for everyone | The free version never lets anyone miss a date; plans show the value before paying |
| Nov 20, 2026 | Lifetime purchase: Product ID `com.grahamdeno.helddear.lifetime`, non-consumable, $9.99, Family Sharing on | A household app; Family Sharing can't be turned off later |
| Nov 20, 2026 | 1.0 includes grouped Christmas, Mother's Day and Father's Day (Epic 1), AI ideas, keepsakes, photo memories and life moments | Graham wants these in the first release |
| Nov 20, 2026 | Mailed cards and family pages ship built in and switched off at build time; the server stays in test mode | Keeps the foundation in place without live payments or shared data in 1.0 |
| Nov 20, 2026 | Shared holidays become one timeline event with a holiday page; plans still save per person; one heads-up six weeks ahead; the user chooses which holidays to keep (Epic 1) | A busy date should read as one event, and planning everyone happens in one place |
| Nov 20, 2026 | Held Dear follows playbook 1.4.0. docs/roadmap.md is the running plan; the plan doc stays the concept and spec reference | One process across all of Graham's apps |
| Nov 13, 2026 | Direction: "Never stuck on what to give." A gift shelf filled all year, ideas about six weeks out, pick, buy, and Home shows the arrival. Phase 1 uses no new APIs or server setup | The real problem was not knowing what to give, not forgetting the date |
| Nov 13, 2026 | Graham does not curate a gift collection. Any server gift search later sends interests only, never names, behind a consent screen | Keeps the work and the privacy promise small |
| Nov 12, 2026 | Horizon look: warm stone, one composed page per main screen, Fraunces names, one oxblood action per screen, time left to right | Replaced Hearth, Quiet and the other rejected directions |
| Nov 12, 2026 | Family pages may store what the user and family add on Held Dear's server: no accounts, links that expire, deleted 30 days after the day | Second network exception, enforced by the guard |
| Nov 12, 2026 | Beyond birthdays: anniversaries, holidays and life moments. Hard times are not included | The person is the product, not the birthday |
| Nov 24, 2026 | Mailed cards back in 1.0, behind a gate: Fable passes the server and card flow by Dec 3, or 1.0 ships with them off | Christmas value, without risking the release date |
| Nov 24, 2026 | Mailed card price $7.99 (was $6.99); statement name HELDDEAR CARD; refunds: automatic if a card can't be placed, resend or refund if not arrived 10 business days after mailing, no refund for a change of mind once mailed | Handwrytten is $4.57 with the stamp and Stripe about $0.50; $7.99 leaves room for a resend |
| Nov 24, 2026 | Last day to order a mailed card for Christmas: Dec 13 (Handwrytten says Dec 14) | A day of margin |
| Nov 12, 2026 | Held Dear Lifetime: $9.99 one time, no subscription | $19.99 was too high for the audience; costs are near zero on the phone |
| Nov 12, 2026 | Handwrytten mails the cards, paid with Apple Pay through Stripe on Held Dear's server | First network exception; nothing stocked or mailed by Graham |
| Nov 11, 2026 | One-time purchase, no subscription. iPhone only. Data stays on the phone apart from the decided exceptions | Founding decisions |

## Release scope

- **1.0:** planned Nov 20, 2026; frozen when this scope is merged. Items, in order: Epic 2 (2.1 to 2.7, R1 to R4),
  Epic 1 (1.1 to 1.5), then polish of the kept features. New ideas go to 1.1.
- **1.0 plan B (Graham, Nov 24, 2026): scope frozen.** 1.0 ships without Held Dear's server: mailed cards and family
  pages are off (build switches `HELDDEAR_MAILED_CARDS` and `HELDDEAR_FAMILY_PAGES`, never set; the privacy guard
  fails if a build or workflow sets them). They come back in 1.1, after the server review's fixes (M1 to M6) are
  shipped. Remaining 1.0 work: accessibility findings UX-1 to UX-9 (Stories A to D) and UX-13 (delete all my data),
  the accessibility walk (Story E), App Privacy answers for a server-free app, a frozen build used for a week, then
  Stage 6 (Fable go-live assessment, listing, screenshots, review notes). Target: submit about Dec 5 to 8. Graham
  asked Opus, in Held Dear Product, to carry this through to Submit (only Graham presses Submit for Review and
  Release). New ideas go to 1.1.
- **Added to 1.0 (Graham, Nov 24, 2026):** the remaining accessibility findings UX-10 (Reduce Motion everywhere),
  UX-12 (a "How Held Dear works" page) and UX-14 (Home's links), and the Held Dear website (home, privacy, support at
  helddear.tangomike.app) the App Store needs.
- **Added to 1.0 (Graham, Nov 24, 2026):** an Appearance setting in You: Match iPhone, Light or Dark.
- **App Privacy answers with mailed cards (Graham, Nov 25, 2026):** collected only to mail a card, linked to the user,
  never for tracking: contact info (name, physical address), other user content (card message, recipient's name and
  address), purchase history (the order record at Stripe and Handwrytten). Payment info not collected (Apple Pay and
  Stripe). Published in App Store Connect only once Fable passes mailed cards; until then "Data Not Collected" stands.
- **Added to 1.0 (approved Nov 25, 2026), mailed cards, from testing build 1057:**
  - **Story 3.1, see a card full screen.** As a sender, I want to open a card full screen and zoom in so that I can
    see it well before I pay. Given the picker, when I tap the card I've picked (or "See it larger", or the VoiceOver
    action), then it opens full screen with the front and, when there is one, the inside; pinch, double-tap and drag
    zoom it, and it never moves past its edges; "Use" picks it and closes.
  - **Story 3.2, enter my return address once.** As a sender, I want my return address kept on this iPhone so that I
    don't type it for every card. Given a saved, complete address, when I mail a card, then the address step is
    skipped and the review shows it with "Change your return address"; I can set or remove it in You > Your profile.
  - **Story 3.3, find my orders later.** As a sender, I want each order kept on this iPhone so that I can find its
    number if I need help. Given a placed order, then You > Mailed cards lists who, which card, the date and the
    order number, with Copy; no addresses; test orders are marked and can be removed.
  - **Story 3.4, the card on the person's year (approved Nov 25, 2026).** As a sender, I want a mailed card's year entry to say what it was
    and show it so that the record means something later. Given a placed order, then the year shows "Handwritten
    [kind] card, mailed [date]", the message as its line, and the card's front as its picture; no row repeats the
    same words twice.
- **Mailed card review decisions (Graham, Nov 25, 2026, Fable findings N1 to N11):** stuck or failed orders are
  reported by Grok's daily order check, from the daily job's report and "ATTENTION mailed card order" log lines (no email
  service).
  The test server keeps Handwrytten's key so its card list works; orders are locked to live payment keys in two places.
  The review screen names both names, both addresses and the Apple Pay payment. App Privacy keeps "Payment info: not
  collected" (Apple Pay's encrypted payment goes straight to Stripe; the server keeps only Stripe's card fingerprint
  for the daily limit). A 300-per-minute limit on card pictures (/_vercel/image) is approved.
- **App Store listing approved (Graham, Nov 25, 2026):** docs/app-store-listing.md. Subtitle "Birthday and holiday
  planner"; written after an independent review of what 1.0 does.
- **Mailed cards review (Nov 25, 2026):** Fable passed PR #152 at 42c15f8 (findings N1 to N11, re-check R1 to R5);
  merged on Graham's go. Server shipped to production at cd2602f on Graham's ship go, Nov 25, 2026
  (dpl_9uTEnEPZj4vv3v4pySoXUG3acLTG); MAILED_CARDS stays unset, so cards answer "paused" until Graham's go.
- **First-use audit decisions (Graham, Nov 25, 2026):** U6, mailed cards ship in 1.0, after two real orders to
  Graham's address (one mailed, one forced to fail and refunded); if either fails, they're switched off. U7, every new
  plan is the plan in parts, starting with three suggested parts; Home's plan buttons and alert taps open it. U8 to U10
  and U12 approved one by one. U13 to U16 go to 1.1.
- **First-use work added to 1.0 (Graham, Nov 25, 2026):** 1.0 isn't frozen yet. A first-use audit (Fable) walks the
  app as a new person through the first week and ranks where people could stall; its fixes may add features. Story 4.1,
  one-time tips: the first time someone reaches a new part (Home, a plan, a holiday page, ideas, the card picker), one
  short line and "Got it", shown once, kept on this iPhone. Tip wording waits for the audit and Graham's read-back.
  Submit moves to about Dec 11 to 12.
- **Purchases approved:** `com.grahamdeno.helddear.lifetime`, non-consumable, $9.99, Family Sharing on (Nov 20,
  2026). Grok creates it after the first 1.0 test build.
- **Go-aheads under playbook 1.4.0:** merge PR #11 (Nov 20).

## Dated checks

- **Nov 21 to Dec 26, 2026, Christmas hand test (Graham):** plan the household's Christmas on one sheet, a row per
  person, with parts, owner, status and date, noting when each was first planned and anything that fell through.
- **Dec 27, 2026, hand test review (Opus with Graham).** Decision rules, set before the test:
  1. Updated at least weekly and useful: the core job is confirmed; build Epic 2 as approved.
  2. Stopped updating within 2 weeks: plans are too heavy; cut 1.0 plans to the Gift part plus owners.
  3. Parts owned by others are where things fell through, or where the sheet helped most: owners stay in the core.
  4. Most planning started more than 21 days out: the inner-ring heads-up moves to the recorded median start.
  5. Planning worked by holiday rather than by person: confirms grouped holidays (Epic 1).

## Backlog

Items in the playbook's item format (items.md). Unordered until Graham ranks them.

### 1. Epic: Shared holidays as one event (approved Nov 20, 2026; in 1.0 scope)
**Goal:** Christmas, Valentine's Day, Mother's Day and Father's Day each show as one event on the timeline. The user
plans everyone for that holiday in one place, and each plan saves to that person.

**Context:** each person's holiday is stored as its own occasion, so six people make six Christmas rows on one date.
Plans already save per person; what's missing is grouping on screen and in alerts. This is the plan doc's stage 3,
"one date, many people". The holiday page reuses the occasion plan (Epic 2, once approved) with a row per person.

#### 1.1 One marker on the timeline
As a user, I want each shared holiday to appear once on my timeline so that a busy date reads as one event.
- Given 6 people with Christmas, when I view Home, then I see one Christmas marker showing how many people, not 6 rows.
- Given only 1 person with Mother's Day, when I view Home, then it still shows as a holiday marker.

#### 1.2 The holiday page
As a user, I want one page per holiday listing everyone and where each plan stands so that I can plan the whole
holiday in one place.
- Given the Christmas page, when I open it, then each person shows one status: no plan, idea picked, ordered,
  arrived or done.
- Given I choose a gift for one person there, when I save, then it appears on that person's page and in their yearly
  record, and I return to the holiday page.
- The holiday page is a browse screen, like Home. Planning one person uses the existing one-decision-per-screen flow.

#### 1.3 Add people from the holiday
As a user, I want to add people to a holiday from its page so that I don't have to visit each person.
- Given the Christmas page, when I tap Add people and pick 3, then each of them gets Christmas.

#### 1.4 One heads-up per holiday
As a user, I want one alert per holiday, six weeks ahead, so that I'm not sent a notification per person.
- Given 6 people with Christmas, when it's six weeks before Christmas, then I get one notification for Christmas
  covering all 6 people.

#### 1.5 Choose your holidays
As a user, I want to choose which shared holidays Held Dear keeps so that only the ones I celebrate appear.
- Given I chose Christmas and Mother's Day, when I add an occasion to a person, then only those holidays are offered.
- Given no one has Christmas yet, when I view Home, then there is no Christmas marker.
- Given I add Christmas to one person, when I view Home, then the Christmas event appears on the timeline.

**Out of scope:** group gifts from several givers (stage 4), budgets, holidays beyond the four (Hanukkah, Easter,
Thanksgiving are a later item).

**Open:** where the user chooses holidays (setup, Settings, or both), settled in Shape.

**Steps:**
1. Words and a Horizon mockup of the timeline marker, the holiday page and choosing holidays (Opus). Graham picks.
2. Confirm stored data doesn't change, or review the migration if it does (Opus; Graham approves a migration).
3. Handoff (Opus).
4. Build (Sonnet).
5. Review the build (Opus).
6. Test build on Graham's go.

### 2. Epic: Held Dear 1.0, plan the whole occasion (approved Nov 20, 2026; in 1.0 scope)
**Goal:** a first release worth $9.99 that does one job well: planning each occasion for your closest people,
including gifts from family.

**Context:** Fable's strategy review (Nov 20) recommended Go with this core job. The evidence is a household's paper
plan for a spouse's birthday: cake (open); card (the daughters color a bouquet); an activity, scheduled with a date; a
gift, ordered from a vendor with a date; a gift from the daughters; a gift from the son. Each occasion already holds
several acts with a "from", so the data model is close.

**Kept from current builds (regression list, no new story):** people from Contacts, birthdays and anniversaries,
heads-ups by ring, the gift shelf through the share sheet, the morning-of message, the yearly line, the way back after
a miss, AI ideas and card words, keepsakes, photo memories, life moments. Each is polished and tested for 1.0.

#### 2.1 Parts
As a user, I want an occasion's plan to hold several parts so that the whole day lives in one place.
- Given a birthday plan, when I add parts, then I can pick from Gift, Card, Cake and The day, or type my own, one tap
  each.

#### 2.2 Owners
As a parent, I want each part to have an owner so that gifts from my kids happen too.
- Given a part, when I set its owner, then it shows "You" or a family member's name.
- Given a part owned by the daughters, then it counts as open until it's marked done.

#### 2.3 Status and date
As a user, I want each part to show where it stands so that I see what's done at a glance.
- States: open, idea, scheduled, ordered, arrived, done. Scheduled and ordered carry a date and, optionally, where
  it came from.
- Given a gift ordered Oct 1 from a named shop, then it reads "Ordered Oct 1, [shop]".

#### 2.4 What's still open
As a user, I want to see unplanned parts so that I act early.
- Given the cake is open 10 days out, then the plan and Home show "Cake not planned". Calm wording, no red badges.

#### 2.5 The shelf feeds the gift
As a user, I want to pick a gift from the shelf so that saved ideas get used.
- Given 3 shelf items for a person, when I open their Gift part, then I can pick one and the part becomes "idea".

#### 2.6 Holidays in 1.0
As a user, I want Christmas, Mother's Day and Father's Day in 1.0 so that I can plan them like any occasion.
- Christmas is grouped as Epic 1 describes. Valentine's Day is hidden in 1.0.

#### 2.7 Free and Lifetime
As a user, I want plans for my 3 closest people free so that I can try the full job before paying.
- Given plans for 3 people, when I start a plan for a 4th, then the Lifetime offer appears; it closes at once and
  appears only there.
- Reminders, the morning-of message and the yearly line stay free for everyone.
- Lifetime adds plans for everyone, all card designs, the Lock Screen widget, AI ideas and keepsakes.

#### Requirements
- **R1. Several recipients:** an occasion can hold several people. Enforced by a unit test on the data model.
- **R2. Mailed cards and family pages off in 1.0:** the code ships, switched off by a build setting. No 1.0 build
  sends anything to the server. Enforced by a CI check on the App Store configuration and the privacy guard.
- **R3. TestFlight-only Lifetime switch:** compiled only into TestFlight builds through a build setting, never into
  an App Store build, never decided by the purchase environment. Enforced by a CI check.
- **R4. No remote switches:** no feature is turned on from the server. Turning on mailed cards or family pages means
  a new, reviewed app update (App Review guideline 2.3.1). Enforced in review.

**Data:** parts, owners, statuses and dates add stored fields. That's a migration: Opus reviews it and Graham approves
it before any build, because his own test data is in the TestFlight builds.

**Out of scope:** mailed cards and family pages for customers, Valentine's Day, ongoing gifts such as a weekly note,
budgets, group gifts from several givers.

**Open:** how early the inner-ring heads-up arrives (the hand test decides; today 21 days).

**Steps:**
1. Words and Horizon mockups of the plan screen (Opus). Graham picks.
2. Migration review (Opus). Graham approves.
3. Handoffs, one per story (Opus).
4. Build (Sonnet).
5. Review the build (Opus).
6. UX audit (Opus).
7. Test build on Graham's go.
8. Stage 6 prep and the Fable go-live assessment.

## Small follow-ups

- **Flaky store test (Nov 25, 2026):** DataFoundationTests.testS3_aFailedCopyLeavesNothingAndIsTriedAgain compares the
  old store's file bytes; SQLite sometimes rewrites the header, so it failed once on PR #155 and passed on a rerun.
  Compare the old store's rows instead. Store tests are always reviewed (Fable).

- **L1 (Fable, low, Nov 25, 2026):** a Stripe 400 with type invalid_request_error should read as declined
  (server/api/order.js, the charge catch). Today it reads as "still being confirmed" and the daily check settles it.
- **L2 (Fable, low):** the daily report sits at a fixed public path, reports/<mode>/order-check.json
  (server/api/cleanup.js). It holds short hashes and Stripe payment ids only; move it under a random path.
- **L3 (Fable, low):** the order check doesn't run without CRON_SECRET. Set in Production Nov 25, 2026; takes effect at
  the next production redeploy.

- Set the repo's default branch to `main`: done Nov 23, 2026 (Grok, on Graham's go).
- **Requirement R2 (approved Nov 24, 2026; from Fable's schema review): test sharing in the test container before it
  ships.** Any feature that shares records between iCloud accounts (planned for 3.2) must first pass a run in the
  `iCloud.com.grahamdeno.helddear.schematest` container: a shared record created, accepted on a second account, edited
  from both sides, and seen on both. Only then can it ship. The Schema Test app never shares a record, so the shared
  database and its record types are untested. Checked by: a Schema Test run that covers sharing, reviewed by Fable.
- Clean up merged branches (see the branch list in the onboarding PR). Not yet approved.

## Shipped

- Nothing released. TestFlight builds 1001 to 1009 (Nov 12 to 14, 2026) were for internal testing.
