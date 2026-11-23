# Someone clicked RSVP on an unfurled Overdrive card.
class SlackRsvpClickJob < ApplicationJob
  queue_as :default

  def perform(slack_id:, channel_id:, ref: nil)
    reply = ->(text) { channel_id ? SlackBot.post_ephemeral(channel: channel_id, user: slack_id, text:) : SlackBot.dm(user: slack_id, text:) }
    finish_url = "#{Overdrive.public_url}/#{ref.present? ? "?ref=#{ref}" : ""}#rsvp"

    user = User.find_by(slack_id:) || user_from_hca_check(slack_id)

    unless user
      return reply.("I couldn't find a Hack Club account linked to your Slack. Finish your RSVP here: #{finish_url}")
    end

    if user.rsvp_blocked?
      return reply.(user.aged_out? ? "Overdrive is for teenagers 18 and under, so you can't RSVP. Sorry!" : "You're not currently eligible to RSVP for Overdrive.")
    end

    if user.rsvp
      InviteToSlackChannelJob.perform_now(user)
      return reply.("You're already RSVP'd for Overdrive! :zap:")
    end

    RsvpForUser.call(user, source: "slack", attrs: { ref: ref.presence })
    reply.("You're in! :zap: You're RSVP'd for *Overdrive*. We'll ping you when it opens in summer 2027. " \
           "Tell us what you're building: #{Overdrive.public_url}")
  end

  private

  # Unknown Slack user: ask HCA whether this Slack account belongs to someone.
  def user_from_hca_check(slack_id)
    result = HackClubAuth.check(slack_id:)
    return nil if result.nil? || result == "not_found"

    eligible = case result
    when "verified_eligible" then true
    when "verified_but_over_18" then false
    end
    User.create!(slack_id:, verification_status: result, ysws_eligible: eligible)
  rescue ActiveRecord::RecordNotUnique
    User.find_by(slack_id:)
  end
end
