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

    it "searches by name, matching real text, not a decorative box" do
      create(:product, name: "Trailhawk Off-Road Scooter")
      create(:product, name: "Boardwalk Cruiser Bicycle")

      get products_path(q: "scooter")
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")

      expect(grid).to have_text("Trailhawk Off-Road Scooter")
      expect(grid).not_to have_text("Boardwalk Cruiser Bicycle")
    end

    it "shows an honest empty state for a search with no matches" do
      create(:product, name: "Trailhawk Off-Road Scooter")

      get products_path(q: "no-such-product-exists")

      expect(response.body).to include("No products match")
    end

    it "filters by real availability" do
      in_stock = create(:product, name: "Available Now Scooter", stock_status: "in_stock")
      sold_out = create(:product, :sold_out, name: "Sold Out Golf Cart")

      get products_path(availability: [ "sold_out" ])
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")

      expect(grid).to have_text(sold_out.name)
      expect(grid).not_to have_text(in_stock.name)
    end

    it "filters by real price range" do
      cheap = create(:product, name: "Budget Scooter", price_cents: 50_00)
      expensive = create(:product, name: "Premium Golf Cart", price_cents: 5_000_00)

      get products_path(min_price: 0, max_price: 100)
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")

      expect(grid).to have_text(cheap.name)
      expect(grid).not_to have_text(expensive.name)
    end

    it "filters by a real variant color" do
      product_with_color = create(:product, name: "Racing Red Scooter")
      create(:product_variant, product: product_with_color, options: { "Color" => "Racing Red" })
      other_product = create(:product, name: "Plain Bicycle")

      get products_path(colors: [ "Racing Red" ])
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")

      expect(grid).to have_text("Racing Red Scooter")
      expect(grid).not_to have_text("Plain Bicycle")
    end

    it "only lists color filter options that belong to the current category, not the whole catalog" do
      scooters = create(:category, name: "Scooters")
      pools = create(:category, name: "Pools")
      scooter_product = create(:product, category: scooters)
      pool_product = create(:product, category: pools)
      create(:product_variant, product: scooter_product, options: { "Color" => "Racing Red" })
      create(:product_variant, product: pool_product, options: { "Color" => "Ocean Blue" })

      get products_path(category: scooters.slug)

      expect(response.body).to include("Racing Red")
      expect(response.body).not_to include("Ocean Blue")
    end

    it "sorts by real price, ascending" do
      create(:product, name: "Expensive Golf Cart", price_cents: 5_000_00)
      create(:product, name: "Cheap Scooter", price_cents: 50_00)

      get products_path(sort: "price_asc")
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")

      products_in_order = grid.all("h3").map { |el| el.text.strip }
      expect(products_in_order.first).to eq("Cheap Scooter")
    end

    it "respects a real per_page selection" do
      category = create(:category)
      3.times { |n| create(:product, category: category, name: "Item #{n}") }

      get products_path(per_page: 12)
      grid = Capybara.string(response.body).find("[data-grid-density-target='grid']")

      expect(grid.all("article").size).to eq(3)
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

    it "disables Add to Cart and Buy It Now for a plain out-of-stock product" do
      product = create(:product, stock_quantity: 0, stock_status: "sold_out")

      get product_path(product)

      page = Capybara.string(response.body)
      expect(page).to have_button("Out of Stock", disabled: true)
      expect(page).to have_button("Buy It Now", disabled: true)
    end

    it "keeps Add to Cart and Buy It Now enabled for an in-stock product" do
      product = create(:product, stock_quantity: 5, stock_status: "in_stock")

      get product_path(product)

      page = Capybara.string(response.body)
      expect(page).to have_button("Add to Cart", disabled: false)
      expect(page).to have_button("Buy It Now", disabled: false)
    end

    it "shows the product's real description, not templated boilerplate" do
      product = create(:product, description: "A genuinely unique description of this exact model.")

      get product_path(product)

      expect(response.body).to include("A genuinely unique description of this exact model.")
      expect(response.body).not_to include("is built around one idea")
    end

    it "shows an honest fallback when safety/care notes are blank" do
      product = create(:product, safety_notes: nil, care_notes: nil)

      get product_path(product)

      expect(response.body).to include("Safety guidance for this model is being added soon.")
      expect(response.body).to include("Care instructions for this model are being added soon.")
    end

    it "shows real safety/care notes when the admin has added them" do
      product = create(:product, safety_notes: "Keep away from open water.", care_notes: "Store indoors when not in use.")

      get product_path(product)

      expect(response.body).to include("Keep away from open water.")
      expect(response.body).to include("Store indoors when not in use.")
    end

    it "records a real view and shows a real (not fabricated) viewer count" do
      product = create(:product)

      expect { get product_path(product) }.to change(ProductView, :count).by(1)

      expect(response.body).to include("1</span> customer is viewing this product")
    end

    it "does not double-count the same visitor viewing again within the current window" do
      product = create(:product)
      get product_path(product)

      expect { get product_path(product) }.not_to change(ProductView, :count)
    end

    it "shows no sale badge without a real compare-at price" do
      product = create(:product, price_cents: 10_000, compare_at_price_cents: nil)

      get product_path(product)

      expect(response.body).not_to include("You save")
    end

    it "shows a real discount once the admin sets a genuine compare-at price" do
      product = create(:product, price_cents: 10_000, compare_at_price_cents: 12_700)

      get product_path(product)

      expect(response.body).to include("−21%")
      expect(response.body).to include("You save")
    end

    it "renders Product structured data with the real price, sku, and availability" do
      product = create(:product, name: "Trailblazer 4x4", price_cents: 149_900, sku: "ZMR-00042", stock_status: "in_stock")

      get product_path(product)

      expect(response.body).to include('"@type":"Product"')
      expect(response.body).to include('"name":"Trailblazer 4x4"')
      expect(response.body).to include('"sku":"ZMR-00042"')
      expect(response.body).to include('"price":"1499.00"')
      expect(response.body).to include('"priceCurrency":"AED"')
      expect(response.body).to include('"availability":"https://schema.org/InStock"')
    end

    it "marks a sold-out product's structured data as OutOfStock" do
      product = create(:product, :sold_out)

      get product_path(product)

      expect(response.body).to include('"availability":"https://schema.org/OutOfStock"')
    end

    it "marks a preorder product's structured data as PreOrder" do
      product = create(:product, stock_status: "preorder")

      get product_path(product)

      expect(response.body).to include('"availability":"https://schema.org/PreOrder"')
    end

    it "marks a product with every variant out of stock as OutOfStock, even though the parent's own stock_status says otherwise" do
      product = create(:product, stock_status: "in_stock")
      create(:product_variant, product: product, stock_quantity: 0)

      get product_path(product)

      expect(response.body).to include('"availability":"https://schema.org/OutOfStock"')
    end

    it "omits aggregateRating from structured data when the product has no reviews yet" do
      product = create(:product)

      get product_path(product)

      expect(response.body).not_to include('"aggregateRating"')
    end

    it "includes aggregateRating in structured data once the product has real reviews" do
      product = create(:product)
      create(:review, product: product, rating: 5)
      create(:review, product: product, rating: 3)

      get product_path(product)

      expect(response.body).to include('"aggregateRating"')
      expect(response.body).to include('"ratingValue":4.0')
      expect(response.body).to include('"reviewCount":2')
    end

    it "renders BreadcrumbList structured data matching the visible breadcrumb" do
      category = create(:category, name: "Bicycles")
      product = create(:product, category: category, name: "Meadowbrook Cruiser")

      get product_path(product)

      expect(response.body).to include('"@type":"BreadcrumbList"')
      expect(response.body).to include('"name":"Bicycles"')
      expect(response.body).to include('"name":"Meadowbrook Cruiser"')
    end

    it "uses the product's own placeholder photo as its Open Graph image, not the sitewide logo" do
      product = create(:product, placeholder_key: "bicycle")

      get product_path(product)

      expect(response.body).to match(%r{<meta property="og:image" content="[^"]*category-bicycle[^"]*">})
    end
  end
end
