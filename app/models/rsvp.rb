class Rsvp < ApplicationRecord
  SOURCES = %w[email hca slack].freeze
  HEARD_FROM = {
    "school_club" => "My school's Hack Club",
    "poster" => "A poster or sticker",
    "slack" => "The Hack Club Slack",
    "friend" => "A friend",
    "social" => "Social media / a creator",
    "other" => "Somewhere else"
  }.freeze

  belongs_to :user, optional: true

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :building, :ref, with: ->(v) { v.strip.presence }

  validates :source, inclusion: { in: SOURCES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :email, uniqueness: true, allow_nil: true
  validates :email, presence: true, unless: :user_id?
  validates :user_id, uniqueness: true, allow_nil: true
  validates :building, length: { maximum: 280 }
  validates :heard_from, inclusion: { in: HEARD_FROM.keys }, allow_blank: true
  validates :ref, length: { maximum: 64 }, format: { with: /\A[\w-]+\z/ }, allow_nil: true

  scope :linked, -> { where.not(user_id: nil) }
  scope :email_only, -> { where(user_id: nil) }

  def linked? = user_id.present?

  def self.stats
    { total: count, linked: linked.count }
  end

  # Attach this RSVP to a Hack Club account. If the user already has an RSVP
  # (say they RSVP'd from Slack, then by email), fold this one into theirs
  # so the person only counts once. Returns the surviving RSVP.
  def link_to!(user)
    return self if self.user_id == user.id

    transaction do
      if (existing = user.rsvp) && existing != self
        existing.update!(
          building: existing.building || building,
          heard_from: existing.heard_from.presence || heard_from,
          ref: existing.ref || ref
        )
        destroy!
        existing
      else
        update!(user: user, linked_at: Time.current)
        self
      end
    end
  end
end
