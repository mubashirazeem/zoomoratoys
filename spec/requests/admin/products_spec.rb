require "rails_helper"

RSpec.describe "Admin::Products", type: :request do
  describe "GET /admin/products" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_products_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "searches products by name or SKU" do
      matching = create(:product, name: "Trailhawk Off-Road Scooter", sku: "TRH-001")
      other = create(:product, name: "Estate Two Seater", sku: "EST-002")

      get admin_products_path(q: "trailhawk")

      expect(response.body).to include(matching.name)
      expect(response.body).not_to include(other.name)
    end

    it "creates a product with real inventory and specifications" do
      category = create(:category)

      expect {
        post admin_products_path, params: {
          product: {
            name: "Trail King E-Scooter",
            sku: "ZMR-99001",
            category_id: category.id,
            placeholder_key: category.placeholder_key,
            price: "1299.50",
            stock_status: "in_stock",
            stock_quantity: 25,
            specifications_text: "Motor: 500W\nRange: 40km"
          }
        }
      }.to change(Product, :count).by(1)

      product = Product.last
      expect(product.price_cents).to eq(129_950)
      expect(product.stock_quantity).to eq(25)
      expect(product.specifications).to eq("Motor" => "500W", "Range" => "40km")
      expect(response).to redirect_to(admin_products_path)
    end

    it "updates a product's stock quantity" do
      product = create(:product, stock_quantity: 5)

      patch admin_product_path(product), params: { product: { stock_quantity: 40 } }

      expect(product.reload.stock_quantity).to eq(40)
    end

    it "updates a product's safety and care notes" do
      product = create(:product, safety_notes: nil, care_notes: nil)

      patch admin_product_path(product), params: {
        product: {
          safety_notes: "Keep away from open water.\nAdult supervision required.",
          care_notes: "Deflate and store indoors when not in use."
        }
      }

      product.reload
      expect(product.safety_notes).to eq("Keep away from open water.\nAdult supervision required.")
      expect(product.care_notes).to eq("Deflate and store indoors when not in use.")
    end

    it "sets a genuine compare-at price to put a product on sale" do
      product = create(:product, price_cents: 10_000, compare_at_price_cents: nil)

      patch admin_product_path(product), params: { product: { compare_at_price: "127.00" } }

      product.reload
      expect(product.compare_at_price_cents).to eq(12_700)
      expect(product.on_sale?).to be true
    end

    it "rejects a compare-at price that isn't a genuine discount" do
      product = create(:product, price_cents: 10_000)

      patch admin_product_path(product), params: { product: { compare_at_price: "80.00" } }

      expect(product.reload.compare_at_price_cents).to be_nil
    end

    it "clears a compare-at price to end a sale" do
      product = create(:product, price_cents: 10_000, compare_at_price_cents: 12_700)

      patch admin_product_path(product), params: { product: { compare_at_price: "" } }

      expect(product.reload.compare_at_price_cents).to be_nil
    end

    it "rejects unpermitted attributes rather than mass-assigning them" do
      product = create(:product)

      patch admin_product_path(product), params: { product: { stock_quantity: 10, id: 999_999 } }

      expect(response).to redirect_to(admin_products_path)
      expect(product.reload.id).not_to eq(999_999)
      expect(product.stock_quantity).to eq(10)
    end

    it "deletes a product with no order history" do
      product = create(:product)

      delete admin_product_path(product)

      expect(response).to redirect_to(admin_products_path)
      expect(Product.exists?(product.id)).to be false
    end

    it "shows a real error instead of crashing when the product has order history" do
      product = create(:product)
      create(:line_item, product: product)

      delete admin_product_path(product)

      expect(response).to redirect_to(admin_products_path)
      follow_redirect!
      expect(response.body).to include("line items exist")
      expect(Product.exists?(product.id)).to be true
    end
  end
end
