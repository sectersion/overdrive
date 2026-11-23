# Program-wide settings. Everything that differs between environments, or that
# we expect to change (channel ids, hosts), comes from ENV, never hardcoded.
module Overdrive
  module_function

  def env(key, default = nil)
    ENV.fetch(key, default).presence || default
  end

  def list(key)
    env(key, "").split(",").map(&:strip).reject(&:empty?)
  end

  # Public origin, e.g. https://overdrive.vaultless.dev
  def public_url = env("PUBLIC_URL", "http://localhost:3000").chomp("/")
  def public_host = URI(public_url).host

  def hca_url = env("HCA_URL", "https://auth.hackclub.com").chomp("/")
  def hca_client_id = env("HCA_CLIENT_ID")
  def hca_client_secret = env("HCA_CLIENT_SECRET")

  # Where email RSVPers go to create a Hack Club account + join Slack.
  # Swap for the Overdrive onboarding link (/join/overdrive) once HQ sets it up.
  def slack_join_url = env("SLACK_JOIN_URL", "https://hackclub.com/slack/")

  def slack_bot_token = env("SLACK_BOT_TOKEN")
  def slack_signing_secret = env("SLACK_SIGNING_SECRET")
  # Channel RSVPers get invited to. An ID like C0123ABCD, not a name.
  def slack_rsvp_channel_id = env("SLACK_RSVP_CHANNEL_ID")
  def slack_enabled? = slack_bot_token.present?

  def turnstile_site_key = env("TURNSTILE_SITE_KEY")
  def turnstile_secret_key = env("TURNSTILE_SECRET_KEY")

  def admin_slack_ids = list("ADMIN_SLACK_IDS")
  def admin_emails = list("ADMIN_EMAILS").map(&:downcase)

  GOAL_HOURS = 500_000
end
