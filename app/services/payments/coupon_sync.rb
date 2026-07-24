module Payments
  # Stripe constraint (confirmed against Stripe's current API docs, see
  # design doc): a PromotionCode only allows updating `active` after
  # creation — code, expiry, and usage limit are frozen forever, and a
  # Coupon's discount amount can never change once created either. So any
  # change other than `active` means retiring the old pair and creating a
  # fresh one.
  class CouponSync
    STRIPE_RELEVANT_ATTRIBUTES = %w[code discount_type discount_value expires_at usage_limit].freeze

    def self.create(coupon)
      new(coupon).create
    end

    def self.update(coupon)
      new(coupon).update
    end

    def self.deactivate(coupon)
      new(coupon).deactivate
    end

    def initialize(coupon)
      @coupon = coupon
    end

    def create
      stripe_coupon = Stripe::Coupon.create(coupon_params)
      promotion_code = Stripe::PromotionCode.create(promotion_code_params(stripe_coupon.id))
      @coupon.update_columns(stripe_coupon_id: stripe_coupon.id, stripe_promotion_code_id: promotion_code.id)
    end

    def update
      if only_active_changed?
        Stripe::PromotionCode.update(@coupon.stripe_promotion_code_id, active: @coupon.active)
      else
        deactivate
        create
      end
    end

    def deactivate
      return if @coupon.stripe_promotion_code_id.blank?

      Stripe::PromotionCode.update(@coupon.stripe_promotion_code_id, active: false)
    end

    private

    def only_active_changed?
      (@coupon.previous_changes.keys & STRIPE_RELEVANT_ATTRIBUTES).empty?
    end

    def coupon_params
      params = { name: @coupon.code, duration: "forever" }
      params[:redeem_by] = @coupon.expires_at.to_i if @coupon.expires_at.present?
      if @coupon.percentage?
        params[:percent_off] = @coupon.discount_value
      else
        params[:amount_off] = @coupon.discount_value * 100
        params[:currency] = "aed"
      end
      params
    end

    def promotion_code_params(stripe_coupon_id)
      # Stripe's current API nests the coupon reference under `promotion`
      # (a top-level `coupon` param existed in older API versions but this
      # account's default version — see config/initializers/stripe.rb —
      # rejects it with "Received unknown parameter: coupon", confirmed via
      # a real API call).
      params = {
        promotion: { type: "coupon", coupon: stripe_coupon_id },
        code: @coupon.code,
        active: @coupon.active
      }
      params[:max_redemptions] = @coupon.usage_limit if @coupon.usage_limit.present?
      params
    end
  end
end
