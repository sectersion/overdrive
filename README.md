# overdrive
500,000 or bust!

Overdrive is a Hack Club YSWS for teenagers who build hardware and software. This repo is its website. Right now it's **v0: landing page + RSVPs**. See [PLAN.md](PLAN.md) for the full program plan.

## What v0 does
- **Landing page.** Grayscale on purpose: the color comes back as the community logs hours (v1).
- **RSVP with Hack Club:** one click through Hack Club Auth. The RSVP is linked to the account, and the person is invited to the Overdrive Slack channel.
- **RSVP with email:** for people without a Hack Club account yet. It's saved as *unlinked*, and the thanks page walks them through joining Slack and linking. A later Hack Club sign-in links the RSVP through a signed cookie or a matching email, so each person counts once.
- **Overdrive Slack bot.** Links to the site unfurl into a card with an **RSVP** button. Clicking it checks the person with Hack Club Auth, records the RSVP, and invites them to the channel. Modeled on [hackclub-community/rsvp](https://github.com/hackclub-community/rsvp). `?ref=` codes carry through.
- `GET /api/stats` returns `{"rsvps":{"total":N,"linked":M}}`.
- **`/admin`:** counts, top refs, where people heard about us, and a CSV export. Admins are set with `ADMIN_SLACK_IDS` / `ADMIN_EMAILS`.

## Stack
Rails 8.1, SQLite (Postgres once we move to Coolify/Orchard), Hotwire, Tailwind v4, Solid Queue/Cache/Cable, OmniAuth (Hack Club Auth), slack-ruby-client, Minitest + WebMock.

## Development
Use WSL/Linux/macOS. Native Windows Ruby isn't supported.

```sh
mise use ruby@3.4        # or any Ruby 3.4
bundle install
cp .env.example .env     # everything is optional in dev
bin/rails db:prepare
bin/dev                  # http://localhost:3000
bin/rails test           # also: bin/rubocop, bin/brakeman
```

You can test Hack Club Auth locally against staging (`HCA_URL=https://hca.dinosaurbbq.org`) with a redirect URI of `http://localhost:3000/auth/hack_club/callback`. For the Slack bot, tunnel to `/slack/events` and `/slack/interactions` (cloudflared, ngrok) and point a test app's manifest at the tunnel.

## Theme rules
All colors come from the CSS variables in `app/assets/tailwind/application.css` (`bg`, `surface`, `ink`, `muted`, `line`, `strong`). **Never use raw Tailwind colors** (`bg-red-500`). Palettes will swap those variables in v1. Status must never rely on color alone, because the site starts gray.

## Deploying (v0 on Nest)
Nest is Hack Club's free community hosting (https://hackclub.app, docs at https://guides.hackclub.app). **Check the Nest-specific steps against the Nest guides or `#nest-help`.** Nest has moved to containers managed from https://dashboard.hackclub.app.

1. Clone, `bundle config set without "development test"`, `bundle install`.
2. Set the production env: everything in `.env.example`, plus `RAILS_ENV=production`, `SECRET_KEY_BASE` (`bin/rails secret`) and `SOLID_QUEUE_IN_PUMA=1`, so jobs run inside the web process and there's no second service.
3. `bin/rails db:prepare && bin/rails assets:precompile`.
4. Run `bin/thrust bin/rails server` under a supervisor (systemd user service or the Nest equivalent) on the port Nest gives you, behind Nest's reverse proxy.
5. Domain: add `overdrive.vaultless.dev` in the Nest dashboard and point the DNS record it asks for at Nest from Cloudflare. Start with Cloudflare's proxy **off** (DNS only) so Nest's proxy can get a TLS certificate.
6. Back up `storage/*.sqlite3`. That file *is* the RSVP list.

Then:
- **Hack Club Auth app:** redirect URI `https://overdrive.vaultless.dev/auth/hack_club/callback`, scopes `email name slack_id verification_status`.
- **Slack app:** create it from `config/slack_manifest.yml`, ask HQ to approve the install, then set `SLACK_BOT_TOKEN`, `SLACK_SIGNING_SECRET` and `SLACK_RSVP_CHANNEL_ID`.
