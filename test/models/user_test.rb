require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "creates a user from an HCA identity" do
    user = User.from_hca_identity(hca_identity)
    assert_equal "ident!abc123", user.hca_id
    assert_equal "orpheus@example.com", user.email
    assert_equal "U0ORPHEUS", user.slack_id
    assert_not user.rsvp_blocked?
  end

  test "claims a Slack-only user on first HCA sign-in" do
    slack_user = User.create!(slack_id: "U0ORPHEUS", verification_status: "pending")
    user = User.from_hca_identity(hca_identity)
    assert_equal slack_user.id, user.id
    assert_equal "ident!abc123", user.hca_id
  end

  test "does not steal a Slack id already held by another HCA account" do
    other = User.create!(hca_id: "ident!other", slack_id: "U0ORPHEUS")
    user = User.from_hca_identity(hca_identity)
    assert_not_equal other.id, user.id
    assert_nil user.slack_id
  end

  test "verified over-18 users are blocked from RSVPing" do
    user = User.from_hca_identity(hca_identity(ysws_eligible: false))
    assert user.aged_out?
    assert user.rsvp_blocked?
  end

  test "unverified users can RSVP" do
    user = User.from_hca_identity(hca_identity(verification_status: "needs_submission", ysws_eligible: false))
    assert_not user.rsvp_blocked?
  end

  test "admin by slack id or email" do
    with_env("ADMIN_SLACK_IDS" => "U0ADMIN, U0OTHER", "ADMIN_EMAILS" => "Boss@Example.com") do
      assert User.new(slack_id: "U0OTHER").admin?
      assert User.new(email: "boss@example.com").admin?
      assert_not User.new(slack_id: "U0NOPE", email: "x@example.com").admin?
    end
  end
end
