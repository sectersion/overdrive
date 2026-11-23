Rails.application.routes.draw do
  root "pages#home"

  # Email RSVP
  resource :rsvp, only: :create do
    get :thanks
  end

  # Hack Club Auth (POST /auth/hack_club starts the flow; OmniAuth handles it)
  get "/auth/hack_club/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  delete "/logout", to: "sessions#destroy", as: :logout

  # Slack bot
  post "/slack/events", to: "slack#events"
  post "/slack/interactions", to: "slack#interactions"

  namespace :api do
    get :stats, to: "stats#show"
  end

  namespace :admin do
    root to: redirect("/admin/rsvps")
    resources :rsvps, only: :index
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
