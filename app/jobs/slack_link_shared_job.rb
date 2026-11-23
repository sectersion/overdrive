# Slack `link_shared` event -> unfurl our links into an RSVP card.
class SlackLinkSharedJob < ApplicationJob
  queue_as :default

  def perform(event)
    unfurls = event.fetch("links", []).filter_map do |link|
      url = link["url"]
      [ url, { blocks: SlackBot.rsvp_card_blocks(ref: SlackBot.ref_from(url)) } ] if SlackBot.our_link?(url)
    end.to_h
    return if unfurls.empty?

    target = if event["unfurl_id"]
      { unfurl_id: event["unfurl_id"], source: event["source"] }
    else
      { channel: event["channel"], ts: event["message_ts"] }
    end

    SlackBot.client.chat_unfurl(**target, unfurls: unfurls.to_json)
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.warn("chat.unfurl failed: #{e.message}")
  end
end
