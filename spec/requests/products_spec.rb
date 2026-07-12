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

      # Scoped to the product grid itself, not the full response body: the
      # header's category mega-menu legitimately references every category's
      # products on every page (by design), so a page-wide "not_to include"
      # would false-positive on any other category's product name.
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")
      expect(grid).to have_text("Boardwalk Cruiser")
      expect(grid).not_to have_text("Fairway Four Classic")
    end

    it "ignores an unknown category filter instead of erroring" do
      create(:product, name: "Ridgecrest 110 Youth ATV")

      get products_path(category: "does-not-exist")

      expect(response).to have_http_status(:success)
    end

    it "paginates and shows a different set of products on page 2" do
      stub_const("ProductsController::PER_PAGE", 2)
      category = create(:category)
      create(:product, category: category, name: "Page One Alpha")
      create(:product, category: category, name: "Page One Beta")
      create(:product, category: category, name: "Page Two Gamma")

      get products_path
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")

      expect(grid).to have_text("Page One Alpha")
      expect(grid).not_to have_text("Page Two Gamma")

      get products_path(page: 2)
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")

      expect(grid).to have_text("Page Two Gamma")
      expect(grid).not_to have_text("Page One Alpha")
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
