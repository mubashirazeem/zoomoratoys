module Payments
  # Shared by Payments::CreateCardOrder (brand-new order + session) and
  # Payments::ResumeCardOrder (a fresh payment attempt for an order that
  # already exists and is still awaiting_payment) — both ultimately need to
  # build the exact same shape of Stripe Checkout Session from an Order's
  # own persisted line_items, so this is the one place that logic lives.
  module StripeCheckoutSessionBuilder
    module_function

    def call(order:, user:, success_url:, cancel_url:)
      # Metadata doesn't propagate between Stripe objects — the top-level
      # metadata: below only lives on the Checkout Session itself.
      # payment_intent_data.metadata is what actually lands on the
      # PaymentIntent (and from there, the Charge), so the order is
      # identifiable from any view of the payment in Stripe's dashboard,
      # not only from the Checkout Session. It's also relied on by
      # Payments::WebhookHandler#handle_completed as a fallback lookup, for
      # the case where this is a *second* session for the same order (the
      # customer abandoned the first one) — see that method's comment.
      order_metadata = {
        order_id: order.id,
        order_number: order.order_number,
        products: order.line_items.includes(:product).map { |li| "#{li.product.name} x#{li.quantity}" }.join(", ")
      }

      Stripe::Checkout::Session.create(
        {
          mode: "payment",
          customer: customer_id_for(user),
          line_items: line_items_for(order),
          invoice_creation: { enabled: true },
          success_url: success_url,
          cancel_url: cancel_url,
          metadata: order_metadata,
          payment_intent_data: { metadata: order_metadata }
        }.merge(discount_params(order))
      )
    end

    def customer_id_for(user)
      return user.stripe_customer_id if user.stripe_customer_id.present?

      customer = Stripe::Customer.create(email: user.email, name: user.full_name, metadata: { user_id: user.id })
      user.update!(stripe_customer_id: customer.id)
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
          quantity: line_item.quantity,
          tax_rates: [ tax_rate_id ]
        }
      end

      if order.gift_wrap_cents.positive?
        gift_wrap_name = order.gift_wrap_name.presence
        items << {
          price_data: {
            currency: "aed",
            unit_amount: order.gift_wrap_cents,
            product_data: { name: gift_wrap_name ? "Gift wrap (#{gift_wrap_name})" : "Gift wrap" }
          },
          quantity: 1,
          tax_rates: [ tax_rate_id ]
        }
      end

      if order.delivery_fee_cents.positive?
        items << {
          price_data: {
            currency: "aed",
            unit_amount: order.delivery_fee_cents,
            product_data: { name: "Express delivery" }
          },
          quantity: 1,
          tax_rates: [ tax_rate_id ]
        }
      end

      items
    end

    # Prices are VAT-inclusive (see Order::VAT_RATE) — this tax rate is
    # created once per Stripe account via `rake stripe:create_tax_rate` and
    # is itself configured `inclusive: true`, so attaching it here makes
    # Stripe's own hosted invoice show the same VAT breakdown as the
    # storefront and the admin invoice, without changing the charged amount.
    def tax_rate_id
      ENV.fetch("STRIPE_TAX_RATE_ID")
    end

    # Reads the order's own coupon — already fixed at creation time
    # (Order.create_from_cart!) — rather than re-deciding eligibility here.
    # order.total_cents already has this exact discount baked in; a resumed
    # payment attempt must charge exactly that amount, not re-evaluate
    # whether the coupon is still redeemable.
    def discount_params(order)
      return {} if order.coupon&.stripe_promotion_code_id.blank?

      { discounts: [ { promotion_code: order.coupon.stripe_promotion_code_id } ] }
    end
  end
end
