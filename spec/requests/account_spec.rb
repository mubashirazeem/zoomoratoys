require "rails_helper"

RSpec.describe "Account", type: :request do
  describe "GET /account" do
    it "redirects an anonymous visitor to sign in" do
      get account_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the dashboard for a signed-in user" do
      user = create(:user, first_name: "Layla")
      sign_in user

      get account_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Welcome back, Layla")
      expect(response.body).to include("Order History")
      expect(response.body).to include("Wishlist")
      expect(response.body).to include("Account Settings")
    end

    it "shows a working Manage Billing link for a user with a real Stripe customer" do
      user = create(:user, stripe_customer_id: "cus_test_123")
      sign_in user

      get account_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Manage Billing")
    end

    it "disables Turbo on the Manage Billing form — Turbo's fetch-based submission can't hand off a cross-origin redirect to Stripe as a real browser navigation, so without this the button just reloads the page instead of ever reaching Stripe" do
      user = create(:user, stripe_customer_id: "cus_test_123")
      sign_in user

      get account_path

      expect(response.body).to match(%r{<form[^>]*data-turbo="false"[^>]*action="/billing_portal"})
    end

    it "opens the Manage Billing form in a new tab, since it navigates the browser away to Stripe" do
      user = create(:user, stripe_customer_id: "cus_test_123")
      sign_in user

      get account_path

      expect(response.body).to match(%r{<form[^>]*target="_blank"[^>]*rel="noopener"[^>]*action="/billing_portal"})
    end

    it "shows no Manage Billing link for a user with no Stripe customer yet" do
      user = create(:user, stripe_customer_id: nil)
      sign_in user

      get account_path

      expect(response.body).not_to include("Manage Billing")
    end

    it "shows the user's real order count" do
      user = create(:user)
      create_list(:order, 2, user: user)
      sign_in user

      get account_path

      expect(response.body).to include(">2</span>")
      expect(response.body).to include("Orders")
    end
  end
end
