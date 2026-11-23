# Public, unauthenticated HCA endpoints.
module HackClubAuth
  module_function

  # GET /api/external/check?slack_id=... -> "verified_eligible" | "verified_but_over_18" |
  # "pending" | "needs_submission" | "rejected" | "not_found". Returns nil if HCA is unreachable.
  def check(slack_id: nil, email: nil)
    params = slack_id ? { slack_id: } : { email: }
    response = connection.get("/api/external/check", params)
    response.success? ? response.body["result"] : nil
  rescue Faraday::Error => e
    Rails.logger.warn("hca check failed: #{e.class}: #{e.message}")
    nil
  end

  def connection
    Faraday.new(url: Overdrive.hca_url, request: { timeout: 5, open_timeout: 3 }) do |f|
      f.response :json
    end
  end
end
