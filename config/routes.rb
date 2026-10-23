Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin (HTTP basic auth: ADMIN_USER / ADMIN_PASSWORD)
  namespace :admin do
    root "dashboard#show"
    resources :ads do
      patch :toggle, on: :member
    end
  end

  # Public API used by apps and websites
  namespace :api do
    namespace :v1 do
      get "ads", to: "ads#index"
      post "ads/:id/impression", to: "ads#impression", as: :ad_impression
    end
  end
  match "api/*path", to: "api/base#preflight", via: :options

  # Tracked click redirect
  get "r/:id", to: "clicks#show", as: :click

  root to: redirect("/admin")
end
