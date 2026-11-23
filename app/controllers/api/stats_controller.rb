module Api
  # GET /api/stats -> { "rsvps": { "total": 123, "linked": 80 } }
  # "linked" = RSVPs tied to a Hack Club account; the rest are unconfirmed emails.
  class StatsController < ActionController::API
    def show
      response.headers["Access-Control-Allow-Origin"] = "*"
      expires_in 1.minute, public: true
      render json: { rsvps: Rsvp.stats }
    end
  end
end
