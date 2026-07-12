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
      expect(response.body).to include("Hi, Layla")
      expect(response.body).to include("Order History")
      expect(response.body).to include("Wishlist")
      expect(response.body).to include("Account Settings")
    end

    it "shows the user's real order count" do
      user = create(:user)
      create_list(:order, 2, user: user)
      sign_in user

      get account_path

      expect(response.body).to include("2 orders")
    end
  end
end
