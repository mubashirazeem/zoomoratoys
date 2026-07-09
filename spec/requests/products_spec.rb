require "rails_helper"

RSpec.describe "Products", type: :request do
  describe "GET /shop" do
    it "succeeds and lists products" do
      product = create(:product, name: "Summit E-Trail 27.5")

      get products_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Summit E-Trail 27.5")
    end

    it "filters by category when given" do
      matching_category = create(:category, name: "Bicycles")
      other_category = create(:category, name: "Golf Carts")
      matching_product = create(:product, category: matching_category, name: "Boardwalk Cruiser")
      other_product = create(:product, category: other_category, name: "Fairway Four Classic")

      get products_path(category: matching_category.slug)

      expect(response.body).to include("Boardwalk Cruiser")
      expect(response.body).not_to include("Fairway Four Classic")
    end

    it "ignores an unknown category filter instead of erroring" do
      create(:product, name: "Ridgecrest 110 Youth ATV")

      get products_path(category: "does-not-exist")

      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /shop/:slug" do
    it "succeeds and shows the product" do
      product = create(:product, name: "Ember Trail Dirt Bike 125")

      get product_path(product)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Ember Trail Dirt Bike 125")
    end

    it "returns 404 for an unknown slug" do
      get product_path("not-a-real-product")

      expect(response).to have_http_status(:not_found)
    end
  end
end
