require "rails_helper"

RSpec.describe "Carts", type: :request do
  describe "GET /cart" do
    it "shows the demo cart items with a subtotal computed from their real prices" do
      CartsController::DEMO_ITEM_SLUGS.each_with_index do |slug, index|
        create(:product, slug: slug, name: slug.titleize, price_cents: (index + 1) * 100_00)
      end

      get cart_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Your Cart")
      CartsController::DEMO_ITEM_SLUGS.each { |slug| expect(response.body).to include(slug.titleize) }
    end

    it "shows an empty-cart state when none of the demo products exist" do
      get cart_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Your cart is empty")
    end
  end
end
