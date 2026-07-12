Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "home#index"

  devise_for :users, controllers: { registrations: "users/registrations" }

  resources :categories, only: [ :index ]
  resources :products, only: [ :index, :show ], param: :slug, path: "shop" do
    resources :reviews, only: [ :create ]
  end
  resources :blog_posts, only: [ :index, :show ], param: :slug, path: "blog"

  get "cart", to: "carts#show", as: :cart
  get "wishlist", to: "wishlists#show", as: :wishlist

  get "account", to: "account#show", as: :account
  get "account/orders", to: "orders#index", as: :account_orders

  get "rentals", to: "pages#rentals", as: :rentals
  get "about", to: "pages#about", as: :about
  get "faq", to: "pages#faq", as: :faq
  get "privacy-policy", to: "pages#privacy_policy", as: :privacy_policy
  get "terms-and-conditions", to: "pages#terms_and_conditions", as: :terms_and_conditions
  get "shipping-and-returns", to: "pages#shipping_and_returns", as: :shipping_and_returns

  get "contact", to: "contact_messages#new", as: :contact
  post "contact", to: "contact_messages#create"

  post "newsletter", to: "newsletter_subscribers#create", as: :newsletter_subscribers
end
