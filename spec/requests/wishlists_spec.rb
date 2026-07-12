require "rails_helper"

RSpec.describe "Wishlists", type: :request do
  describe "GET /wishlist" do
    it "shows the demo wishlist items" do
      WishlistsController::DEMO_ITEM_SLUGS.each do |slug|
        create(:product, slug: slug, name: slug.titleize)
      end

      get wishlist_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Wishlist")
      WishlistsController::DEMO_ITEM_SLUGS.each { |slug| expect(response.body).to include(slug.titleize) }
    end

    it "shows an empty-wishlist state when none of the demo products exist" do
      get wishlist_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Your wishlist is empty")
    end
  end
end
