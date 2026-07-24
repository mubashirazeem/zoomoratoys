require "rails_helper"

RSpec.describe "CartCoupons", type: :request do
  describe "POST /cart_coupon" do
    it "applies a real, redeemable coupon" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      coupon = create(:coupon, code: "SAVE20")

      post cart_coupon_path, params: { code: "save20" } # case-insensitive

      expect(response).to redirect_to(cart_path)
      expect(Cart.last.coupon).to eq(coupon)
    end

    it "rejects an unknown code" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }

      post cart_coupon_path, params: { code: "NOTREAL" }

      follow_redirect!
      expect(response.body).to include("That coupon code")
    end

    it "rejects an expired coupon" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      create(:coupon, :expired, code: "OLDCODE")

      post cart_coupon_path, params: { code: "OLDCODE" }

      expect(Cart.last.coupon).to be_nil
    end
  end

  describe "DELETE /cart_coupon" do
    it "removes the applied coupon" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      create(:coupon, code: "SAVE20")
      post cart_coupon_path, params: { code: "SAVE20" }

      delete cart_coupon_path

      expect(Cart.last.coupon).to be_nil
    end
  end
end
