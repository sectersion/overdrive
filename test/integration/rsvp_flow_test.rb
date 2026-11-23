require "test_helper"

class RsvpFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "landing page renders with the counter" do
    Rsvp.create!(email: "a@example.com", source: "email")
    get root_path
    assert_response :success
    assert_select "h1", /500,000/
    assert_select "#rsvp", /1/
  end

  test "email RSVP, then Hack Club sign-in links it via the cookie" do
    get root_path(ref: "poster-ohio")
    post rsvp_path, params: { rsvp: { email: "Kid@Example.com", building: "a synth", heard_from: "poster" } }
    assert_redirected_to thanks_rsvp_path
    rsvp = Rsvp.last
    assert_equal "kid@example.com", rsvp.email
    assert_equal "poster-ohio", rsvp.ref
    assert_not rsvp.linked?

    follow_redirect!
    assert_select "h1", /You're in/
    assert_select "button", /Link it/

    # Signs in with an HCA account under a *different* email; the cookie still links them.
    mock_hca_login(primary_email: "kid.personal@example.com")
    assert_enqueued_with(job: InviteToSlackChannelJob) do
      get "/auth/hack_club/callback"
    end
    assert_redirected_to thanks_rsvp_path
    assert_equal 1, Rsvp.count
    assert rsvp.reload.linked?
    assert_equal "ident!abc123", rsvp.user.hca_id
  end

  test "Hack Club sign-in links an email RSVP by matching email" do
    rsvp = Rsvp.create!(email: "orpheus@example.com", source: "email")
    mock_hca_login
    get "/auth/hack_club/callback"
    assert_equal 1, Rsvp.count
    assert rsvp.reload.linked?
  end

  test "one-click Hack Club RSVP creates a linked RSVP" do
    mock_hca_login
    get "/auth/hack_club/callback"
    assert_redirected_to thanks_rsvp_path
    assert_equal "hca", Rsvp.sole.source
    assert Rsvp.sole.linked?
  end

  test "repeat email RSVP doesn't duplicate" do
    2.times { post rsvp_path, params: { rsvp: { email: "a@example.com" } } }
    assert_equal 1, Rsvp.count
  end

  test "email RSVP for an address already linked to a Hack Club RSVP doesn't duplicate" do
    mock_hca_login
    get "/auth/hack_club/callback"
    delete logout_path
    cookies.delete(:rsvp_id)
    post rsvp_path, params: { rsvp: { email: "orpheus@example.com" } }
    assert_equal 1, Rsvp.count
  end

  test "invalid email re-renders the form" do
    post rsvp_path, params: { rsvp: { email: "nope" } }
    assert_response :unprocessable_entity
    assert_equal 0, Rsvp.count
  end

  test "over-18 Hack Club users can't RSVP" do
    mock_hca_login(ysws_eligible: false)
    get "/auth/hack_club/callback"
    assert_redirected_to root_path(anchor: "rsvp")
    assert_equal 0, Rsvp.count
  end

  test "turnstile failure blocks email RSVP" do
    stub_request(:post, Turnstile::VERIFY_URL).to_return(body: { success: false }.to_json)
    with_env("TURNSTILE_SECRET_KEY" => "secret") do
      post rsvp_path, params: { rsvp: { email: "a@example.com" }, "cf-turnstile-response" => "bad" }
    end
    assert_equal 0, Rsvp.count
  end

  test "stats api" do
    Rsvp.create!(email: "a@example.com", source: "email")
    get api_stats_path
    assert_equal({ "rsvps" => { "total" => 1, "linked" => 0 } }, response.parsed_body)
  end

  test "admin requires an admin account" do
    get admin_rsvps_path
    assert_response :unauthorized

    with_env("ADMIN_SLACK_IDS" => "U0ORPHEUS") do
      mock_hca_login
      OmniAuth.config.before_callback_phase { |env| env["omniauth.params"] = { "intent" => "admin" } }
      get "/auth/hack_club/callback"
      OmniAuth.config.before_callback_phase = nil
      assert_redirected_to admin_rsvps_path
      assert_equal 0, Rsvp.count, "admin sign-in shouldn't RSVP"

      get admin_rsvps_path(format: :csv)
      assert_response :success
      assert_match "created_at,source", response.body
    end
  end
end
