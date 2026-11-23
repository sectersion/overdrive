# Cloudflare Turnstile server-side verification. Disabled (always passes) when
# no secret key is configured, so local dev works without keys.
module Turnstile
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze

  module_function

  def enabled? = Overdrive.turnstile_secret_key.present?

  def verify(token, remote_ip: nil)
    return true unless enabled?
    return false if token.blank?

    response = Faraday.post(VERIFY_URL, { secret: Overdrive.turnstile_secret_key, response: token, remoteip: remote_ip })
    JSON.parse(response.body)["success"] == true
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn("turnstile verify failed: #{e.class}: #{e.message}")
    false
  end
end
