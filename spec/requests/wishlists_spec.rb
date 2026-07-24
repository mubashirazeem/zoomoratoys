require "rails_helper"

RSpec.describe "Wishlists", type: :request do
  describe "GET /wishlist" do
    it "redirects an anonymous visitor to sign in — a wishlist needs an account to persist against" do
      get wishlist_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows an empty-wishlist state for a signed-in user with nothing saved" do
      sign_in create(:user)

      get wishlist_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Your wishlist is empty")
    end

    it "shows the signed-in user's real wishlisted products" do
      user = create(:user)
      product = create(:product, name: "Ridgecrest 110 Youth ATV")
      create(:wishlist_item, user: user, product: product)
      sign_in user

      get wishlist_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Wishlist")
      expect(response.body).to include("Ridgecrest 110 Youth ATV")
    end
  end
end
