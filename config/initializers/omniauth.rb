require Rails.root.join("lib/omniauth/strategies/hack_club")

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :hack_club,
    Overdrive.hca_client_id,
    Overdrive.hca_client_secret,
    client_options: { site: Overdrive.hca_url }
end

# POST-only auth requests (CSRF-protected by omniauth-rails_csrf_protection).
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = ->(env) { SessionsController.action(:failure).call(env) }
