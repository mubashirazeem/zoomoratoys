require "rails_helper"

RSpec.describe "Carts", type: :request do
  describe "GET /cart" do
    it "shows an empty-cart state for a visitor with nothing added" do
      get cart_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Your cart is empty")
    end

    it "shows real items added via a guest cookie cart, with a real subtotal" do
      product = create(:product, name: "Trailhawk Off-Road Scooter", price_cents: 100_00)

      post cart_items_path, params: { product_id: product.slug, quantity: 2 }
      get cart_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Trailhawk Off-Road Scooter")
      expect(response.body).to include("AED 200")
    end

    it "shows a signed-in user's own cart" do
      user = create(:user)
      product = create(:product, name: "Boardwalk Cruiser")
      sign_in user
      post cart_items_path, params: { product_id: product.slug }

      get cart_path

      expect(response.body).to include("Boardwalk Cruiser")
    end

    it "warns and blocks checkout when a cart item has gone out of stock since it was added" do
      product = create(:product, name: "Trailhawk Off-Road Scooter", stock_quantity: 2)
      post cart_items_path, params: { product_id: product.slug, quantity: 2 }
      product.update!(stock_quantity: 0)

      get cart_path

      expect(response.body).to include("Out of stock")
      expect(response.body).to include("Resolve the stock issues")
    end

    it "allows checkout normally when everything in the cart is actually available" do
      product = create(:product, name: "Trailhawk Off-Road Scooter", stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug, quantity: 2 }

      get cart_path

      expect(response.body).not_to include("Resolve the stock issues")
    end
  end
end
