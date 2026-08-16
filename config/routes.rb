Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "home#index"

  devise_for :users, controllers: { registrations: "users/registrations" }
  devise_for :admin_users

  namespace :admin do
    root to: "dashboard#show"
    resources :categories, except: [ :show ]
    resources :promotional_banners, except: [ :show ]
    resources :customer_highlights, except: [ :show ]
    resources :products, except: [ :show ] do
      resources :variants, controller: "product_variants", except: [ :show ]
    end
    resources :orders, only: [ :index, :new, :create, :show, :update ] do
      member do
        get :packing_slip
        get :invoice
        post :refund
      end
    end
    resources :customers, only: [ :index, :show ]
    resources :coupons, except: [ :show ]
    resources :blog_posts, except: [ :show ]
    get "sales-reports", to: "sales_reports#show", as: :sales_reports
  end

  resources :categories, only: [ :index ]
  resources :products, only: [ :index, :show ], param: :slug, path: "shop" do
    resources :reviews, only: [ :create ]
  end
  resources :blog_posts, only: [ :index, :show ], param: :slug, path: "blog"

  get "cart", to: "carts#show", as: :cart
  resources :cart_items, only: [ :create, :update, :destroy ]
  resource :cart_coupon, only: [ :create, :destroy ]

  get "wishlist", to: "wishlists#show", as: :wishlist
  post "wishlist_items/:product_id/toggle", to: "wishlist_items#toggle", as: :toggle_wishlist_item

  post "currency", to: "currencies#update", as: :currency

  resource :checkout, only: [ :show, :create ]
  get "checkout/confirmation/:order_number", to: "checkouts#confirmation", as: :checkout_confirmation
  resource :billing_portal, only: :create, controller: "billing_portal"

  get "account", to: "account#show", as: :account
  get "account/orders", to: "orders#index", as: :account_orders
  get "account/orders/:id", to: "orders#show", as: :order
  post "account/orders/:id/resume_payment", to: "orders#resume_payment", as: :resume_payment_order
  resources :addresses, path: "account/addresses", except: [ :show ]

  get "rentals", to: "pages#rentals", as: :rentals
  get "about", to: "pages#about", as: :about
  get "faq", to: "pages#faq", as: :faq
  get "privacy-policy", to: "pages#privacy_policy", as: :privacy_policy
  get "terms-and-conditions", to: "pages#terms_and_conditions", as: :terms_and_conditions
  get "shipping-and-returns", to: "pages#shipping_and_returns", as: :shipping_and_returns

  get "contact", to: "contact_messages#new", as: :contact
  post "contact", to: "contact_messages#create"

  post "newsletter", to: "newsletter_subscribers#create", as: :newsletter_subscribers

  post "/stripe/webhooks", to: "stripe_webhooks#create"
end
