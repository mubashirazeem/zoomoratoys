Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "home#index"

  resources :categories, only: [ :index ]
  resources :products, only: [ :index, :show ], param: :slug, path: "shop"

  get "about", to: "pages#about", as: :about

  get "contact", to: "contact_messages#new", as: :contact
  post "contact", to: "contact_messages#create"

  post "newsletter", to: "newsletter_subscribers#create", as: :newsletter_subscribers
end
