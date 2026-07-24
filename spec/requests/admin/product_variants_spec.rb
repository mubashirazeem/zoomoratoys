require "rails_helper"

RSpec.describe "Admin::ProductVariants", type: :request do
  describe "GET /admin/products/:product_id/variants" do
    it "redirects an anonymous visitor to admin sign in" do
      product = create(:product)

      get admin_product_variants_path(product)

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "creates a real variant with parsed options" do
      product = create(:product)

      expect {
        post admin_product_variants_path(product), params: {
          product_variant: { sku: "ZMR-VAR-001", stock_quantity: 15, options_text: "Color: Racing Red\nSize: Large" }
        }
      }.to change(ProductVariant, :count).by(1)

      variant = ProductVariant.last
      expect(variant.options).to eq("Color" => "Racing Red", "Size" => "Large")
      expect(response).to redirect_to(admin_product_variants_path(product))
    end

    it "deletes a variant with no cart references" do
      product = create(:product)
      variant = create(:product_variant, product: product)

      delete admin_product_variant_path(product, variant)

      expect(response).to redirect_to(admin_product_variants_path(product))
      expect(ProductVariant.exists?(variant.id)).to be false
    end

    it "deletes a variant currently sitting in a customer's cart, clearing that cart item too" do
      product = create(:product)
      variant = create(:product_variant, product: product)
      cart_item = create(:cart_item, product: product, product_variant: variant)

      delete admin_product_variant_path(product, variant)

      expect(response).to redirect_to(admin_product_variants_path(product))
      expect(ProductVariant.exists?(variant.id)).to be false
      expect(CartItem.exists?(cart_item.id)).to be false
    end
  end
end
