ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Temporarily set ENV vars (Overdrive config reads ENV on every call).
    def with_env(vars)
      old = vars.keys.to_h { |k| [ k, ENV[k] ] }
      vars.each { |k, v| ENV[k] = v }
      SlackBot.reset_client!
      yield
    ensure
      old.each { |k, v| ENV[k] = v }
      SlackBot.reset_client!
    end

    def hca_identity(**overrides)
      {
        "id" => "ident!abc123",
        "primary_email" => "orpheus@example.com",
        "first_name" => "Orpheus",
        "last_name" => "Dino",
        "slack_id" => "U0ORPHEUS",
        "verification_status" => "verified",
        "ysws_eligible" => true
      }.merge(overrides.transform_keys(&:to_s))
    end
  end
end

class ActionDispatch::IntegrationTest
  def mock_hca_login(**overrides)
    OmniAuth.config.test_mode = true
    identity = hca_identity(**overrides)
    OmniAuth.config.mock_auth[:hack_club] = OmniAuth::AuthHash.new(
      provider: "hack_club", uid: identity["id"], extra: { identity: identity }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:hack_club] = nil
  end
end
