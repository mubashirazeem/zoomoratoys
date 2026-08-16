module Payments
  # Creates an Order the exact same way Pay on Delivery does — same
  # row-locked stock check, same atomicity — then creates the Stripe
  # Checkout Session inside that same database transaction. If Stripe
  # fails, the whole transaction (including the stock reservation) rolls
  # back together. See docs/superpowers/specs/2026-07-19-stripe-integration-design.md
  # ("Money safety") for why this ordering is deliberate.
  #
  # Trade-off, deliberately accepted: this holds the row locks taken by
  # Order.create_from_cart! for the duration of the Stripe API round-trip
  # (typically well under a second). The alternative — creating the Stripe
  # session first, outside any transaction — reopens the "charged but no
  # order exists" risk this design exists to close. Correctness wins here.
  #
  # If the customer abandons *this* session without paying (closes the tab,
  # hits back), Payments::ResumeCardOrder is what lets them start a fresh
  # payment attempt for the same already-created order later — this class
  # only ever runs once per order, at the very first checkout attempt.
  class CreateCardOrder
    def self.call(...)
      new(...).call
    end

    def initialize(cart:, user:, shipping_attributes:, success_url_for:, cancel_url:, gift_wrap: false, gift_wrap_cents: 0,
                   gift_wrap_name: nil, delivery_method: "standard", delivery_fee_cents: 0)
      @cart = cart
      @user = user
      @shipping_attributes = shipping_attributes
      @success_url_for = success_url_for
      @cancel_url = cancel_url
      @gift_wrap = gift_wrap
      @gift_wrap_cents = gift_wrap_cents
      @gift_wrap_name = gift_wrap_name
      @delivery_method = delivery_method
      @delivery_fee_cents = delivery_fee_cents
    end

    def call
      checkout_url = nil

      ActiveRecord::Base.transaction do
        order = Order.create_from_cart!(
          cart: @cart, user: @user, shipping_attributes: @shipping_attributes,
          gift_wrap: @gift_wrap, gift_wrap_cents: @gift_wrap_cents, gift_wrap_name: @gift_wrap_name,
          delivery_method: @delivery_method, delivery_fee_cents: @delivery_fee_cents, payment_method: "card",
          discount_cents: applied_discount_cents, coupon: applicable_coupon
        )
        session = StripeCheckoutSessionBuilder.call(
          order: order, user: @user, success_url: @success_url_for.call(order), cancel_url: @cancel_url
        )
        order.update!(stripe_checkout_session_id: session.id)
        checkout_url = session.url
      end

      checkout_url
    end

    private

    # Pre-applies the coupon already selected on the cart page (existing
    # feature, unchanged) rather than Stripe's own allow_promotion_codes,
    # which would let a customer type in *any* valid code on Stripe's
    # hosted page — the two are mutually exclusive on a Checkout Session.
    #
    # Both the Stripe-side discount and the amount recorded on the Order
    # (see Order.create_from_cart!'s discount_cents:) derive from this same
    # check, so the two can never disagree about whether a coupon applies.
    #
    # Known limitation, not fixed here: if gift wrap and a *percentage*
    # coupon are combined, Stripe's session-level percent_off also discounts
    # the separately-added gift-wrap line item, while applied_discount_cents
    # (via Cart#discount_cents) only discounts the line items. The two stay
    # in sync for fixed-amount coupons and for any coupon with no gift wrap;
    # percentage-coupon-plus-gift-wrap is a rare combination left as a known
    # gap pending a dedicated fix.
    def applicable_coupon
      return nil unless @cart.coupon&.redeemable? && @cart.coupon.stripe_promotion_code_id.present?

      @cart.coupon
    end

    def applied_discount_cents
      applicable_coupon ? @cart.discount_cents : 0
    end
  end
end
