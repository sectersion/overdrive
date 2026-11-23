require "test_helper"

class RsvpTest < ActiveSupport::TestCase
  test "normalizes and validates email" do
    rsvp = Rsvp.create!(email: "  Orpheus@Example.COM ", source: "email")
    assert_equal "orpheus@example.com", rsvp.email
    assert_not Rsvp.new(email: "orpheus@example.com", source: "email").valid?
    assert_not Rsvp.new(email: "not-an-email", source: "email").valid?
  end

  test "requires an email or a user" do
    assert_not Rsvp.new(source: "email").valid?
  end

  test "rejects junk refs" do
    assert_not Rsvp.new(email: "a@example.com", source: "email", ref: "<script>").valid?
    assert Rsvp.new(email: "a@example.com", source: "email", ref: "poster-ohio_2").valid?
  end

  test "link_to! attaches an email RSVP to a user" do
    rsvp = Rsvp.create!(email: "a@example.com", source: "email")
    user = User.create!(hca_id: "ident!1")
    assert_equal rsvp, rsvp.link_to!(user)
    assert_equal user, rsvp.reload.user
    assert rsvp.linked_at
  end

  test "link_to! folds a duplicate into the user's existing RSVP" do
    user = User.create!(hca_id: "ident!1")
    existing = Rsvp.create!(user:, source: "slack")
    dupe = Rsvp.create!(email: "a@example.com", source: "email", building: "a robot", heard_from: "poster", ref: "flyer")

    assert_equal existing, dupe.link_to!(user)
    assert_not Rsvp.exists?(dupe.id)
    existing.reload
    assert_equal "a robot", existing.building
    assert_equal "poster", existing.heard_from
    assert_equal "flyer", existing.ref
    assert_equal 1, Rsvp.count
  end

  test "stats" do
    Rsvp.create!(email: "a@example.com", source: "email")
    Rsvp.create!(user: User.create!(hca_id: "ident!1"), source: "hca")
    assert_equal({ total: 2, linked: 1 }, Rsvp.stats)
  end
end
