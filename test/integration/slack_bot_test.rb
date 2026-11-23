require "test_helper"

class SlackBotTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  SECRET = "test-signing-secret".freeze
  ENV_VARS = {
    "SLACK_SIGNING_SECRET" => SECRET,
    "SLACK_BOT_TOKEN" => "xoxb-test",
    "SLACK_RSVP_CHANNEL_ID" => "C0OVERDRIVE",
    "PUBLIC_URL" => "https://overdrive.vaultless.dev"
  }.freeze

  def signed_post(path, body, content_type:)
    ts = Time.now.to_i.to_s
    sig = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", SECRET, "v0:#{ts}:#{body}")
    post path, params: body, headers: {
      "Content-Type" => content_type, "X-Slack-Request-Timestamp" => ts, "X-Slack-Signature" => sig
    }
  end

  def click_rsvp(slack_id: "U0KID", ref: "")
    payload = { type: "block_actions", user: { id: slack_id }, channel: { id: "C0GENERAL" },
                actions: [ { action_id: SlackBot::RSVP_ACTION_ID, value: ref } ] }
    signed_post "/slack/interactions", URI.encode_www_form(payload: payload.to_json), content_type: "application/x-www-form-urlencoded"
  end

  setup do
    @slack = stub_request(:post, %r{https://slack.com/api/.*}).to_return(
      headers: { "Content-Type" => "application/json" }, body: { ok: true, channel: { id: "D0DM" } }.to_json
    )
  end

  test "rejects bad signatures" do
    with_env(ENV_VARS) do
      post "/slack/events", params: { type: "url_verification", challenge: "x" }.to_json,
        headers: { "Content-Type" => "application/json", "X-Slack-Request-Timestamp" => Time.now.to_i.to_s, "X-Slack-Signature" => "v0=nope" }
      assert_response :unauthorized
    end
  end

  test "answers url_verification" do
    with_env(ENV_VARS) do
      signed_post "/slack/events", { type: "url_verification", challenge: "abc" }.to_json, content_type: "application/json"
      assert_equal({ "challenge" => "abc" }, response.parsed_body)
    end
  end

  test "unfurls our links with an RSVP button" do
    with_env(ENV_VARS) do
      event = { type: "event_callback", event: { type: "link_shared", channel: "C1", message_ts: "1.2",
        links: [ { url: "https://overdrive.vaultless.dev/?ref=club-ny" }, { url: "https://example.com" } ] } }
      perform_enqueued_jobs do
        signed_post "/slack/events", event.to_json, content_type: "application/json"
      end
      assert_response :ok

      assert_requested(:post, "https://slack.com/api/chat.unfurl") do |req|
        unfurls = JSON.parse(Rack::Utils.parse_query(req.body)["unfurls"])
        unfurls.keys == [ "https://overdrive.vaultless.dev/?ref=club-ny" ] &&
          unfurls.values.first["blocks"].to_json.include?(SlackBot::RSVP_ACTION_ID) &&
          unfurls.values.first["blocks"].to_json.include?("club-ny")
      end
    end
  end

  test "RSVP click from an eligible unknown user creates user + RSVP and invites them" do
    stub_request(:get, "https://auth.hackclub.com/api/external/check?slack_id=U0KID")
      .to_return(headers: { "Content-Type" => "application/json" }, body: { result: "verified_eligible" }.to_json)

    with_env(ENV_VARS) do
      perform_enqueued_jobs { click_rsvp(ref: "club-ny") }
    end

    rsvp = Rsvp.sole
    assert_equal "slack", rsvp.source
    assert_equal "club-ny", rsvp.ref
    assert_equal "U0KID", rsvp.user.slack_id
    assert_requested(:post, "https://slack.com/api/conversations.invite") { |r| r.body.include?("C0OVERDRIVE") && r.body.include?("U0KID") }
    assert_requested(:post, "https://slack.com/api/chat.postEphemeral") { |r| CGI.unescape(r.body).include?("You're in") }
  end

  test "RSVP click from a Slack user with no Hack Club account points them to the site" do
    stub_request(:get, "https://auth.hackclub.com/api/external/check?slack_id=U0KID")
      .to_return(headers: { "Content-Type" => "application/json" }, body: { result: "not_found" }.to_json)

    with_env(ENV_VARS) do
      perform_enqueued_jobs { click_rsvp }
    end

    assert_equal 0, Rsvp.count
    assert_requested(:post, "https://slack.com/api/chat.postEphemeral") { |r| CGI.unescape(r.body).include?("overdrive.vaultless.dev") }
  end

  test "RSVP click from an over-18 user is refused" do
    stub_request(:get, "https://auth.hackclub.com/api/external/check?slack_id=U0KID")
      .to_return(headers: { "Content-Type" => "application/json" }, body: { result: "verified_but_over_18" }.to_json)

    with_env(ENV_VARS) do
      perform_enqueued_jobs { click_rsvp }
    end

    assert_equal 0, Rsvp.count
    assert_requested(:post, "https://slack.com/api/chat.postEphemeral") { |r| CGI.unescape(r.body).include?("18 and under") }
  end

  test "second click says already RSVP'd" do
    user = User.create!(slack_id: "U0KID", verification_status: "verified_eligible", ysws_eligible: true)
    Rsvp.create!(user:, source: "slack")

    with_env(ENV_VARS) do
      perform_enqueued_jobs { click_rsvp }
    end

    assert_equal 1, Rsvp.count
    assert_requested(:post, "https://slack.com/api/chat.postEphemeral") { |r| CGI.unescape(r.body).include?("already") }
  end
end
