# Slack Events API + interactivity endpoints. Slack wants a 200 within 3s, so
# we verify, enqueue, and return immediately.
class SlackController < ActionController::Base
  skip_forgery_protection
  before_action :verify_slack_signature

  # POST /slack/events
  def events
    payload = JSON.parse(raw_body)

    case payload["type"]
    when "url_verification"
      render json: { challenge: payload["challenge"] }
    when "event_callback"
      event = payload["event"] || {}
      SlackLinkSharedJob.perform_later(event.slice("channel", "message_ts", "unfurl_id", "source", "links")) if event["type"] == "link_shared"
      head :ok
    else
      head :ok
    end
  end

  # POST /slack/interactions (application/x-www-form-urlencoded, payload=<json>)
  def interactions
    payload = JSON.parse(params.require(:payload))

    if payload["type"] == "block_actions"
      action = payload.fetch("actions", []).find { |a| a["action_id"] == SlackBot::RSVP_ACTION_ID }
      if action
        SlackRsvpClickJob.perform_later(
          slack_id: payload.dig("user", "id"),
          channel_id: payload.dig("channel", "id") || payload.dig("container", "channel_id"),
          ref: action["value"].presence
        )
      end
    end

    head :ok
  end

  private

  def raw_body
    @raw_body ||= request.raw_post
  end

  def verify_slack_signature
    ok = SlackBot.valid_signature?(
      timestamp: request.headers["X-Slack-Request-Timestamp"],
      signature: request.headers["X-Slack-Signature"],
      body: raw_body
    )
    head :unauthorized unless ok
  end
end
