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
- **1.0 scope:** planned Nov 20 after Fable's strategy review (Go). Core job: plan the whole occasion. See
  "Release scope" and Epics 1 and 2.
- **Christmas hand test** runs Nov 21 to Dec 26 on paper (see "Dated checks").
- **Built Nov 20 (PRs #14, #15, #16):** data foundation, occasion plan, holiday page with readiness per person,
  suggested parts by relationship, shelf to gift, free plan limit, build switches (R2, R3). Test build 1010 from
  `main` at 04b3527, uploaded under Graham's one-time exemption.
- **Next:** Graham tests build 1010 (including the device check: his data survives the upgrade), then the UX audit
  and the 1.0 remainder (Held Dear Product, Opus).

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
| Nov 20, 2026 | App map approved: three tabs always visible (Coming up, People, Ideas); one Person page per person reached from anywhere, with each upcoming day as a section; holiday pages open people with that holiday on top; item details is the only level below a Person page; never more than two levels below a tab | Every screen popping up over the last left no sense of where you are |
| Nov 20, 2026 | One-time playbook exemption: Opus built, self-reviewed and merged PR #16 and uploaded test build 1010 the same day | Get 1.0 into Graham's hands fast |
| Nov 20, 2026 | A part's step and its completion agree: reaching the ready step completes it, leaving it undoes that. A plan with several parts, or any part set on the plan screen, drives Home and the occasion's status by readiness; single plans from the older flow keep today's behavior | One answer to "is this done" everywhere |
| Nov 20, 2026 | Migration review approved: added fields only, versioned schema, a migration test, never crash on open, no bulk rewrite (M1 to M4) | Protects existing test data and every future update |
| Nov 20, 2026 | Birthday plan mockup approved: parts with family step words, who it's from (a person or a group), relationship-based suggestions, a calm time-aware note, and the first part not started as the main action | Graham's paper plan, as an app screen |
| Nov 20, 2026 | 1.0 scope reopened once to add: readiness per person from their own plan, family step words with the last step as ready, suggested parts by relationship (1.6) and a relationship field | They make the holiday page work as mocked up |
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
| Nov 12, 2026 | Held Dear Lifetime: $9.99 one time, no subscription | $19.99 was too high for the audience; costs are near zero on the phone |
| Nov 12, 2026 | Handwrytten mails the cards, paid with Apple Pay through Stripe on Held Dear's server | First network exception; nothing stocked or mailed by Graham |
| Nov 11, 2026 | One-time purchase, no subscription. iPhone only. Data stays on the phone apart from the decided exceptions | Founding decisions |

## Release scope

- **1.0:** planned Nov 20, 2026; frozen when this scope is merged. Items, in order: Epic 2 (2.1 to 2.7, R1 to R4),
  Epic 1 (1.1 to 1.6 and the relationship requirement), then polish of the kept features. New ideas go to 1.1.
- **Purchases approved:** `com.grahamdeno.helddear.lifetime`, non-consumable, $9.99, Family Sharing on (Nov 20,
  2026). Grok creates it after the first 1.0 test build.
- **Go-aheads under playbook 1.4.0:** merge PR #11, PR #12, PR #14 (data foundation), PR #15 (occasion plan) and PR #16 (exemption) (Nov 20); test build 1010 at 04b3527 and test build 1011 at 26dabd1 (PR #17, feedback on 1010) (Nov 20, exemption). Scope reopened once on Nov 20 (see
  Decision log).

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
As a user, I want one page per holiday listing everyone and how ready each person is so that I can plan the whole
holiday in one place.
- Each person's readiness comes from their own plan for that holiday: ready when every part of it is at its last
  step. People can have different parts, so each counts their own steps.
- Given a spouse with 4 parts, 2 ready, then the holiday page shows "2 of 4 ready" as a bar with one segment per part.
- Given a brother with 1 part, ready, then he shows "Ready".
- Given I move a part to its last step, then that person's readiness, the holiday page and Home all update.
- The holiday page shows how many people are ready and how many things are ready, and offers the least-ready person
  next as its one main action.
- Approved mockup: https://claude.ai/artifact/4kya3FCLNtXNTjJtr6Hfw5 (Nov 20, 2026).
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

#### 1.6 Suggested parts by relationship
As a parent, I want each person's holiday plan to start with what families usually plan for that relationship so that
I'm not building every list from scratch.
- Christmas suggestions: spouse or partner: Gift, Stocking, Card, Gift from the kids. Child: Gift, From Santa,
  Stocking. Parent or grandparent: Gift, Card. Sibling or in-law: Gift. Teacher, coach or neighbor: Small gift or card.
- Given a person is my daughter, when she joins Christmas, then her plan starts with Gift, From Santa and Stocking.
- Given a suggestion doesn't fit, when I remove it, then readiness counts only what's left.
- Birthdays get their own suggested set, settled in Shape.

#### Requirement: relationship on each person
Each person has a relationship to the user (for example wife, son, mother, brother), read from the Contacts
relationship label where set, otherwise asked with one tap. Stored data change: Opus reviews the migration, Graham
approves. Enforced by a unit test on the suggestion rules.

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
- Given a birthday plan, when I tap Add something, then I see what families often plan for that relationship (for a
  spouse's birthday: Gift, Card, Cake, Flowers, Dinner out, Gift from the kids, Breakfast in bed), with parts already
  in the plan marked Added, plus Something else to type my own.
- The plan shows the name large, the relationship and age, a readiness bar with one segment per part, and
  "2 of 6 ready".
- Approved mockup: https://claude.ai/artifact/4kya3FCLNtXNTjJtr6Hfw5, Birthday plan (Nov 20, 2026).

#### 2.2 Owners
As a parent, I want each part to have an owner so that gifts from my kids happen too.
- Given a part, when I set who it's from, then I can pick You, one household member, or a group of them (for
  example two daughters together, or The kids), and the plan shows "From [names]".
- Given a part owned by the daughters, then it counts as open until it's marked done.

#### 2.3 Steps and notes
As a user, I want each part to show where it stands in words families use so that I see what's ready at a glance.
- Each kind of part has its own steps; the last step is ready:
  - Gift, Stocking, From Santa: Not started, Have an idea, Bought, Wrapped.
  - Card: Not started, Have an idea, Written.
  - Made by the kids: Not started, Have an idea, Making it, Finished.
  - The day (an outing, a dinner): Not started, Have an idea, Booked.
  - Cake, Flowers: Not started, Have an idea, Ordered or baking, Ready.
  - Something else (typed by the user): Not started, Have an idea, Ready.
- Tapping a part opens it: one list of its steps to pick from, and who it's from.
- A part can carry a short note and a date, such as "arrives Dec 12" or where it came from.
- Given a gift bought from a named shop that arrives Dec 12, then it reads "Bought" with the note
  "[shop], arrives Dec 12".

#### 2.4 What's still open
As a user, I want to see unplanned parts so that I act early.
- Given the cake is not started, then the plan shows a calm note, such as "Cake isn't started yet. Cakes are usually
  ordered about a week ahead, so there's time." No red, no badges. The note grows more direct only as that kind's
  usual lead time gets close.
- The plan's one main action offers the first part not started ("Plan the cake").

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

**Data (migration review approved Nov 20, 2026):** all changes are added fields with defaults; nothing is renamed or
removed.
- Act (a plan part) gains `label`, `step`, `ownerIDs` (empty means "You"), `note` and `sortOrder` (default 0).
- Person gains `relationship` (from the Contacts relationship label, otherwise asked with one tap).
- No stored change for grouped holidays, the single holiday heads-up, several recipients (already stored) or the
  chosen holidays (a setting).
- Existing parts get their step when read: a completed gift is Wrapped, a gift with an arrival date is Bought, a gift
  with a title or shelf item is Have an idea, otherwise Not started; a completed card is Written; a dinner with a date
  or completed is Booked; call and message plans use Not started and Done and still close on their own. Greetings
  are not parts.
- **M1. Versioned schema:** today's model is version 1 and 1.0 is version 2, with a declared lightweight migration.
- **M2. Migration test:** a test opens a version 1 database with sample data from current builds, migrates it, and
  checks that every person, occasion, part, shelf item and yearly line survives with the right step.
- **M3. Never crash on open:** if the database can't be opened, the old file is kept untouched, the app opens empty
  and says so calmly, and it never crashes in a loop.
- **M4. No bulk rewrite:** steps for existing parts are worked out when read and stored only when the user changes
  one.

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

- Set the repo's default branch to `main` (Grok, needs Graham's go). Not yet approved.
- Clean up merged branches (see the branch list in the onboarding PR). Not yet approved.

## Shipped

- Nothing released. TestFlight builds 1001 to 1009 (Nov 12 to 14, 2026) were for internal testing.
