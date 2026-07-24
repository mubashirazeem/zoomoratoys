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
  class CreateCardOrder
    def self.call(...)
      new(...).call
    end

    def initialize(cart:, user:, shipping_attributes:, success_url_for:, cancel_url:, gift_wrap: false, gift_wrap_cents: 0)
      @cart = cart
      @user = user
      @shipping_attributes = shipping_attributes
      @success_url_for = success_url_for
      @cancel_url = cancel_url
      @gift_wrap = gift_wrap
      @gift_wrap_cents = gift_wrap_cents
    end

    def call
      checkout_url = nil

      ActiveRecord::Base.transaction do
        order = Order.create_from_cart!(
          cart: @cart, user: @user, shipping_attributes: @shipping_attributes,
          gift_wrap: @gift_wrap, gift_wrap_cents: @gift_wrap_cents, payment_method: "card",
          discount_cents: applied_discount_cents, coupon: applicable_coupon
        )
        session = build_checkout_session(order)
        order.update!(stripe_checkout_session_id: session.id)
        checkout_url = session.url
      end

      checkout_url
    end

    private

    def build_checkout_session(order)
      # Metadata doesn't propagate between Stripe objects — the top-level
      # metadata: below only lives on the Checkout Session itself.
      # payment_intent_data.metadata is what actually lands on the
      # PaymentIntent (and from there, the Charge), so the order is
      # identifiable from any view of the payment in Stripe's dashboard,
      # not only from the Checkout Session.
      order_metadata = { order_id: order.id, order_number: order.order_number }

      Stripe::Checkout::Session.create(
        {
          mode: "payment",
          customer: stripe_customer_id,
          line_items: line_items_for(order),
          invoice_creation: { enabled: true },
          success_url: @success_url_for.call(order),
          cancel_url: @cancel_url,
          metadata: order_metadata,
          payment_intent_data: { metadata: order_metadata }
        }.merge(discount_params)
      )
    end

    def stripe_customer_id
      return @user.stripe_customer_id if @user.stripe_customer_id.present?

      customer = Stripe::Customer.create(email: @user.email, name: @user.full_name, metadata: { user_id: @user.id })
      @user.update!(stripe_customer_id: customer.id)
      customer.id
    end

    def line_items_for(order)
      items = order.line_items.includes(:product).map do |line_item|
        {
          price_data: {
            currency: "aed",
            unit_amount: line_item.price_cents,
            product_data: { name: line_item.product.name }
          },
          quantity: line_item.quantity
        }
      end

      if order.gift_wrap_cents.positive?
        items << {
          price_data: {
            currency: "aed",
            unit_amount: order.gift_wrap_cents,
            product_data: { name: "Gift wrap" }
          },
          quantity: 1
        }
      end

      items
    end

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

    def discount_params
      return {} unless applicable_coupon

      { discounts: [ { promotion_code: applicable_coupon.stripe_promotion_code_id } ] }
    end
  end
end
