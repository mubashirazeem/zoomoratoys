require "rails_helper"

RSpec.describe Cart, type: :model do
  describe "#discount_cents" do
    it "is 0 with no coupon applied" do
      cart = create(:cart)
      create(:cart_item, cart: cart, product: create(:product, price_cents: 10_000))

      expect(cart.discount_cents).to eq(0)
    end

    it "computes a percentage discount off the real total" do
      cart = create(:cart, coupon: create(:coupon, discount_type: "percentage", discount_value: 20))
      create(:cart_item, cart: cart, product: create(:product, price_cents: 10_000))

      expect(cart.discount_cents).to eq(2_000)
      expect(cart.total_after_discount_cents).to eq(8_000)
    end

    it "computes a fixed-amount discount, capped at the cart total" do
      cart = create(:cart, coupon: create(:coupon, discount_type: "fixed_amount", discount_value: 500))
      create(:cart_item, cart: cart, product: create(:product, price_cents: 10_000))

      expect(cart.discount_cents).to eq(10_000) # 500 AED discount capped at the 100 AED total
    end

    it "is 0 once the coupon is no longer redeemable" do
      cart = create(:cart, coupon: create(:coupon, :expired))
      create(:cart_item, cart: cart, product: create(:product, price_cents: 10_000))

      expect(cart.discount_cents).to eq(0)
    end
  end
end
