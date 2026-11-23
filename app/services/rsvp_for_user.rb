# Ensures a Hack Club–linked user has exactly one RSVP, folding in any email
# RSVP made earlier (via the browser cookie or a matching email).
#
#   result = RsvpForUser.call(user, source: "hca", cookie_rsvp: rsvp)
#   result.rsvp      # the surviving RSVP
#   result.created?  # true if this is their first RSVP
class RsvpForUser
  Result = Data.define(:rsvp, :created) do
    def created? = created
  end

  def self.call(...) = new(...).call

  def initialize(user, source:, cookie_rsvp: nil, attrs: {})
    @user = user
    @source = source
    @cookie_rsvp = cookie_rsvp
    @attrs = attrs
  end

  def call
    candidates = [ @cookie_rsvp, (@user.email.present? && Rsvp.email_only.find_by(email: @user.email)) ]
    candidates.select { |r| r && !r.linked? }.uniq.each { |r| r.link_to!(@user) }
    @user.reload

    created = @user.rsvp.nil?
    rsvp = begin
      @user.rsvp || @user.create_rsvp!(source: @source, **@attrs)
    rescue ActiveRecord::RecordNotUnique
      created = false # a double-click raced us; theirs won
      @user.reload.rsvp
    end
    InviteToSlackChannelJob.perform_later(@user) if @user.slack_id.present?

    Result.new(rsvp:, created:)
  end
end
