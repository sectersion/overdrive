# The Overdrive Slack bot. Modeled on hackclub-community/rsvp: links to the
# site unfurl into a card with an RSVP button; clicking it RSVPs you without
# leaving Slack and invites you to the Overdrive channel.
module SlackBot
  RSVP_ACTION_ID = "overdrive_rsvp".freeze

  module_function

  def client
    @client ||= Slack::Web::Client.new(token: Overdrive.slack_bot_token)
  end

  def reset_client! = @client = nil

  # Is this a link to our site that should unfurl into an RSVP card?
  def our_link?(url)
    uri = URI.parse(url)
    uri.host == Overdrive.public_host && (uri.path.blank? || uri.path == "/" || uri.path == "/rsvp")
  rescue URI::InvalidURIError
    false
  end

  def ref_from(url)
    ref = Rack::Utils.parse_query(URI.parse(url).query.to_s)["ref"]
    ref if ref.to_s.match?(/\A[\w-]{1,64}\z/)
  rescue URI::InvalidURIError
    nil
  end

  def rsvp_card_blocks(ref: nil)
    count = Rsvp.count
    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*OVERDRIVE*  ·  500,000 hours or bust\n" \
                "Build hardware and software, log your hours, and help bring the color back. Opens summer 2027."
        }
      },
      {
        type: "actions",
        elements: [
          {
            type: "button",
            text: { type: "plain_text", text: "RSVP", emoji: true },
            style: "primary",
            action_id: RSVP_ACTION_ID,
            value: ref.to_s
          }
        ]
      },
      {
        type: "context",
        elements: [ { type: "mrkdwn", text: "#{ActiveSupport::NumberHelper.number_to_delimited(count)} #{"person".pluralize(count)} RSVP'd" } ]
      }
    ]
  end

  def post_ephemeral(channel:, user:, text:)
    client.chat_postEphemeral(channel:, user:, text:)
  rescue Slack::Web::Api::Errors::SlackError => e
    # Ephemerals fail in some contexts (e.g. DMs the bot isn't in). Fall back to a DM.
    Rails.logger.info("ephemeral failed (#{e.message}); DMing instead")
    dm(user:, text:)
  end

  def dm(user:, text:)
    channel = client.conversations_open(users: user).dig("channel", "id")
    client.chat_postMessage(channel:, text:)
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.warn("slack DM to #{user} failed: #{e.message}")
  end

  # Invite a user to the RSVP channel. Already-in-channel is fine.
  def invite_to_rsvp_channel(slack_id)
    channel = Overdrive.slack_rsvp_channel_id
    return false if channel.blank?

    begin
      client.conversations_join(channel:)
    rescue Slack::Web::Api::Errors::SlackError
      # private channel, or already a member
    end

    client.conversations_invite(channel:, users: slack_id)
    true
  rescue Slack::Web::Api::Errors::SlackError => e
    return true if e.message == "already_in_channel"
    Rails.logger.warn("invite #{slack_id} to #{channel} failed: #{e.message}")
    false
  end

  # Verify Slack's request signature (https://api.slack.com/authentication/verifying-requests-from-slack).
  def valid_signature?(timestamp:, signature:, body:, now: Time.now.to_i)
    secret = Overdrive.slack_signing_secret
    return false if secret.blank? || timestamp.blank? || signature.blank?
    return false if (now - timestamp.to_i).abs > 5.minutes.to_i

    expected = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", secret, "v0:#{timestamp}:#{body}")
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end
end
