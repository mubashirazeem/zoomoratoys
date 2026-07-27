require "rails_helper"

RSpec.describe "CartCoupons", type: :request do
  describe "POST /cart_coupon" do
    it "applies a real, redeemable coupon", vcr: { cassette_name: "cart_coupons/apply_valid" } do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      coupon = create(:coupon, code: "SAVE20")
      Payments::CouponSync.create(coupon)

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

    it "rejects a coupon that was never actually synced to Stripe" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      create(:coupon, code: "UNSYNCED") # stripe_promotion_code_id left blank on purpose

      post cart_coupon_path, params: { code: "UNSYNCED" }

      expect(Cart.last.coupon).to be_nil
    end

    it "rejects a coupon Stripe itself shows as inactive, even though it's still active locally",
       vcr: { cassette_name: "cart_coupons/rejects_stripe_deactivated" } do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      coupon = create(:coupon, code: "DRIFTED")
      Payments::CouponSync.create(coupon)
      Stripe::PromotionCode.update(coupon.reload.stripe_promotion_code_id, active: false)

      post cart_coupon_path, params: { code: "DRIFTED" }

      expect(coupon.reload.active?).to be true # local flag never touched
      expect(Cart.last.coupon).to be_nil
    end

    it "redirects back to checkout when applied from there",
       vcr: { cassette_name: "cart_coupons/apply_from_checkout" } do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      coupon = create(:coupon, code: "CHECKOUT20")
      Payments::CouponSync.create(coupon)

      post cart_coupon_path, params: { code: "CHECKOUT20" }, headers: { "HTTP_REFERER" => checkout_path }

      expect(response).to redirect_to(checkout_path)
    end
  end

  describe "DELETE /cart_coupon" do
    it "removes the applied coupon", vcr: { cassette_name: "cart_coupons/remove" } do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      coupon = create(:coupon, code: "REMOVE20")
      Payments::CouponSync.create(coupon)
      post cart_coupon_path, params: { code: "REMOVE20" }

      delete cart_coupon_path

      expect(Cart.last.coupon).to be_nil
    end
  end
end
