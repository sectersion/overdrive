# Overdrive — Plan

> 500,000 or bust. A 3–6 month Hack Club YSWS (hardware + software) aiming to break Hack Club's all-time **shipped hours** record, ending in 5 flagship summits.

This doc records decisions made so far. Open questions are marked **OPEN**.

---

## 1. Program rules that the site must encode

| Topic | Decision |
|---|---|
| Payout model | 1 shipped hour = $8.50 of program budget; ~$5 returns to the builder (shop currency, tickets, hardware funding, flight stipends). Grant math: 10 hrs = 1 grant = $85. |
| When an hour counts | When its project **ships** (passes review). Hours are logged against a project, rewards arrive at ship. |
| Two counters, always labeled | **Hours logged** (drives global color). **Hours shipped** (the record; the 500k goal lives here only). Never present logged hours as shipped. |
| Hour evidence | Lapse (timelapse video), devlogs/journals, Hackatime, commit history. |
| AI slop | Fully AI-made projects aren't eligible. Signals: Lapse coverage ratio, commit cadence, Hackatime agreement, devlog cadence, live check for high-hour ships. AI detection is only ever a **flag for a human**, never an auto-reject. |
| Grayscale hook | Site, docs and branding launch fully grayscale. Grayscale *is* the marketing hook ("bring the color back"). |
| Global color | Discrete palette unlocks at community **logged-hour** milestones. |
| Personal color | Discrete palette unlocks at personal **shipped-hour** milestones, independent of global state. Users pick their own palette from what they've unlocked. A colorful profile on a gray site is the point. |
| Drops | Cut. |
| Summits | 5 summits. Tickets are expensive shop items with limited stock, first come first served. **1 ticket per person per summit** (one person can attend all 5). Flight stipends are sold in the shop too. Needed later: announced drop times rotated across time zones, guardian consent before checkout, refund policy. |
| Slack | Encourage Slack use, but **no rewards for Slack activity**. Make Slack the place where the program's moments happen (RSVP, ship threads, color unlocks). |
| Identity | Everything goes through Hack Club Auth (HCA). Email RSVP is the only exception, and it's a path toward HCA. |
| Fulfillment | Through HCB (card grants) and Theseus (physical mail), the same patterns Stardance used. |

## 2. Phases

### v0: RSVP (now → launch) *(built, see README)*
- Landing page: the simple pitch, grayscale, sponsor logos later.
- **RSVP two ways:**
  - **HCA one-click**: sign in → RSVP recorded as verified → auto-invited to `#overdrive`.
  - **Email**: email + Turnstile → recorded as **unconfirmed** → success page sends them to HCA signup / Slack join. No emails are sent in v0 (Loops comes once HQ sponsors us).
  - Linking: a signed cookie set on email RSVP links a later HCA sign-in in the same browser. A matching email also links them. One person counts once.
- **Overdrive Slack bot** (built into the Rails app, modeled on [hackclub-community/rsvp](https://github.com/hackclub-community/rsvp)):
  - Unfurls `overdrive.vaultless.dev` links with an **RSVP** button.
  - On click: find the user by Slack ID, otherwise check eligibility with HCA `GET /api/external/check?slack_id=`, record the RSVP, post an ephemeral confirmation, invite them to `#overdrive`.
  - Ineligible or unknown → ephemeral "finish your RSVP" link to the web flow.
- Public RSVP counter (verified vs total) and a `/api/stats` JSON endpoint.
- Referral codes (`?ref=`) to attribute posters and school clubs.
- Minimal admin: RSVP list, CSV export.
- **Hosting:** Nest (`hackclub.app`), at `overdrive.vaultless.dev` via Cloudflare. Moves to Coolify/Orchard (and a hackclub.com domain) when HQ onboards us.

### v1: Launch (summer 2027)
- Projects, devlogs, linking Hackatime, Lapse and GitHub.
- Logged and shipped counters; global and personal palette unlocks.
- Slack-native moments: ship/devlog threads in one channel posted under the builder's name; color unlocks posted to `#overdrive-bulletin`; personal unlocks posted in the builder's project thread.
- "I'm working" button → Lapse + a standing huddle in `#overdrive-cowork`. The Slack API can't start or invite to huddles, so this uses a huddle link. Ask HQ for a Lapse "recording started" webhook.
- Ship → review → ledger payout → Unified YSWS DB (Airtable) sync.
- **OPEN:** shipping opens at launch, so v1 needs at least a basic review queue (approve/reject + notes). Either build that into v1, or open shipping a few weeks after launch.

### v2: Scale (mid-program)
- Review pods: pod assignment, Pod Lead audits, reviewer agreement metrics, appeals.
- Shop: HCB card grants and Theseus fulfillment; summit tickets and flight stipends.
- Opt-in streak pings (Fallen-style crossed-off mentions), maybe teams.

## 3. Engineering approach

- **Stack:** Rails 8, SQLite for v0 on Nest (Postgres when we move hosts), Hotwire, Tailwind, Solid Queue/Cache, Flipper feature flags, `slack-ruby-client`, OmniAuth (Hack Club Auth).
- **One app on `main`.** v0 is just what's switched on. Unfinished features sit behind Flipper flags and merge weekly through short-lived branches. No long-lived "real site" branch.
- **Copy from Stardance:** an immutable ledger (`balance = sum(entries)`), hours snapshotted at ship time, aasm order state machines with idempotent fulfillment, the HCA login/eligibility service, thin service classes per integration, latency-named job queues.
- **Don't copy:** feature sprawl, 1000+ line models, hardcoded Slack IDs (put them in config), two test frameworks, hidden fraud rules.
- **Don't copy from Fallen:** the huddle bot on undocumented Slack APIs and a browser cookie; high-frequency DMs.
- **Palettes:** CSS custom properties per palette and theme; global state picks the site palette, the profile owner's choice styles their profile. Status colors (approved/rejected) must still be readable in grayscale: use icons and text, not only color.

### Core data model (grows by phase)
`users`, `rsvps` (v0) → `projects`, `devlogs`, `ship_events`, `reviews`, `ledger_entries`, `palettes`, `global_milestones`, `user_palette_unlocks` (v1) → `review_pods`, `shop_items`, `orders`, `summits`, `tickets` (v2)

## 4. Slack setup

Channels (create by hand, under your name). The RSVP channel is configured by ID (`SLACK_RSVP_CHANNEL_ID`), never by name:
- `#overdrive`: main; RSVPers get invited. *Currently owned by someone else; in talks. Fall back to another name if needed.*
- `#overdrive-bulletin`: announcements, color unlocks
- `#overdrive-help`: questions
- Later: `#overdrive-cowork`, a ships channel

The bot needs HQ approval to be installed in the Hack Club workspace. Likely scopes: `chat:write`, `links:read`, `links:write`, `channels:manage` or `channels:join` + invite, `users:read`, `im:write`, plus an unfurl domain for `overdrive.vaultless.dev`.

## 5. HQ asks (Zach call)
1. HCA: register the app; get `hq_official` status (needed later for `address`/`birthdate`); an Overdrive onboarding scenario (`/join/overdrive` → auto-join channels).
2. Slack: approval to install the Overdrive bot.
3. Loops account for Overdrive.
4. Hosting move: Coolify vs Orchard, and timing; a hackclub.com domain.
5. Later: Lapse app registration (+ "recording started" webhook), HCB org + API access, Unified YSWS DB access.
6. Sign-off on the grant model / sponsor split.

## 6. Open questions
- **OPEN:** v0 live date (it drives the school-club poster push).
- RSVP fields (decided): email or HCA, optional "what might you build?", "how did you hear about us?", automatic `?ref=`.
- **OPEN:** v1 review queue vs delaying shipping (see v1).
- **OPEN:** Summit drop schedule, guardian consent flow, refund policy.
