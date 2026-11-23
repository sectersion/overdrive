require "omniauth-oauth2"

module OmniAuth
  module Strategies
    # Hack Club Auth (auth.hackclub.com). Community apps can request:
    # openid profile email name slack_id verification_status
    class HackClub < OmniAuth::Strategies::OAuth2
      option :name, "hack_club"
      option :scope, "email name slack_id verification_status"
      option :client_options, {
        site: "https://auth.hackclub.com",
        authorize_url: "/oauth/authorize",
        token_url: "/oauth/token"
      }

      uid { identity["id"] }

      info do
        {
          email: identity["primary_email"],
          first_name: identity["first_name"],
          last_name: identity["last_name"]
        }
      end

      extra { { "identity" => identity } }

      # GET /api/v1/me -> { identity: { id, primary_email, slack_id, verification_status, ysws_eligible, ... } }
      def identity
        @identity ||= access_token.get("/api/v1/me").parsed.fetch("identity", {})
      end

      # HCA matches redirect_uri exactly; drop the query string OmniAuth appends.
      def callback_url
        full_host + callback_path
      end
    end
  end
end
