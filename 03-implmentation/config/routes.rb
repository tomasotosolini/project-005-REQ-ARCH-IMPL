Rails.application.routes.draw do
  get  "login",  to: "sessions#new",     as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  get    "guests/new",          to: "guests/lifecycle#new",     as: :new_guest
  get    "guests",              to: "guests/guests#index",      as: :guests
  post   "guests",              to: "guests/lifecycle#create"
  get    "guests/:name",        to: "guests/guests#show",       as: :guest
  post   "guests/:name/start",  to: "guests/lifecycle#start",   as: :start_guest
  post   "guests/:name/stop",   to: "guests/lifecycle#stop",    as: :stop_guest
  delete "guests/:name",        to: "guests/lifecycle#destroy"

  root to: "guests/guests#index"

  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
