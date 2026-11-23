class InviteToSlackChannelJob < ApplicationJob
  queue_as :default

  def perform(user)
    return unless Overdrive.slack_enabled? && user.slack_id.present?
    SlackBot.invite_to_rsvp_channel(user.slack_id)
  end
end
