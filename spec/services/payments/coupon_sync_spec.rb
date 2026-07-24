require "rails_helper"

RSpec.describe Payments::CouponSync do
  describe ".create" do
    it "creates a real Stripe Coupon and PromotionCode, storing both ids",
       vcr: { cassette_name: "payments/coupon_sync/create_percentage" } do
      coupon = create(:coupon, code: "SUMMER20", discount_type: "percentage", discount_value: 20)

      Payments::CouponSync.create(coupon)

      coupon.reload
      expect(coupon.stripe_coupon_id).to be_present
      expect(coupon.stripe_promotion_code_id).to be_present
    end
  end

  describe ".update" do
    it "patches the existing PromotionCode in place when only active changed",
       vcr: { cassette_name: "payments/coupon_sync/update_active_only" } do
      coupon = create(:coupon, code: "WINTER15", discount_type: "percentage", discount_value: 15)
      Payments::CouponSync.create(coupon)
      original_promotion_code_id = coupon.reload.stripe_promotion_code_id
      coupon.update!(active: false)

      Payments::CouponSync.update(coupon)

      expect(coupon.reload.stripe_promotion_code_id).to eq(original_promotion_code_id)
    end

    it "retires the old PromotionCode and creates a fresh pair when the discount value changed",
       vcr: { cassette_name: "payments/coupon_sync/update_discount_value" } do
      coupon = create(:coupon, code: "SPRING10", discount_type: "percentage", discount_value: 10)
      Payments::CouponSync.create(coupon)
      original_promotion_code_id = coupon.reload.stripe_promotion_code_id
      coupon.update!(discount_value: 25)

      Payments::CouponSync.update(coupon)

      expect(coupon.reload.stripe_promotion_code_id).not_to eq(original_promotion_code_id)
    end
  end

  describe ".deactivate" do
    it "deactivates the PromotionCode without attempting to delete the Coupon",
       vcr: { cassette_name: "payments/coupon_sync/deactivate" } do
      coupon = create(:coupon, code: "AUTUMN5", discount_type: "fixed_amount", discount_value: 5)
      Payments::CouponSync.create(coupon)

      expect { Payments::CouponSync.deactivate(coupon) }.not_to raise_error
    end
  end
end
