class User < ApplicationRecord
  has_one :rsvp, dependent: :nullify

  normalizes :email, with: ->(e) { e.strip.downcase }

  # Hack Club Auth says this person is verified but over 18.
  def aged_out?
    verification_status.in?(%w[verified verified_but_over_18]) && ysws_eligible == false
  end

  def rejected?
    verification_status.in?(%w[ineligible rejected])
  end

  def rsvp_blocked?
    aged_out? || rejected?
  end

  def admin?
    Overdrive.admin_slack_ids.include?(slack_id) || (email.present? && Overdrive.admin_emails.include?(email))
  end

  def display_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email || slack_id
  end

  # Find or build a user from a Hack Club Auth /api/v1/me identity hash.
  # Matching order (as Stardance does): HCA id, then Slack id, then email.
  def self.from_hca_identity(identity)
    identity = identity.with_indifferent_access
    email = identity[:primary_email]&.strip&.downcase
    user = find_by(hca_id: identity[:id]) ||
      (identity[:slack_id].present? && find_by(slack_id: identity[:slack_id], hca_id: nil)) ||
      (email.present? && find_by(email: email, hca_id: nil)) ||
      new

    # A different account already holds this Slack id. Don't steal it.
    slack_id = identity[:slack_id].presence
    slack_id = user.slack_id if slack_id && where(slack_id: slack_id).where.not(id: user.id).exists?

    user.assign_attributes(
      hca_id: identity[:id],
      email: email.presence || user.email,
      first_name: identity[:first_name],
      last_name: identity[:last_name],
      slack_id: slack_id || user.slack_id,
      verification_status: identity[:verification_status],
      ysws_eligible: identity[:ysws_eligible],
      last_signed_in_at: Time.current
    )
    user.save!
    user
  end
end
