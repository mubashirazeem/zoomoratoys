module Payments
  # Full refunds only (see design doc's non-goals) — no amount param, which
  # tells Stripe to refund the entire payment intent.
  class RefundIssuer
    def self.call(order:)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      # Captured before the refund flips status to "refunded" — see
      # Order#stock_restorable? for why shipped/delivered orders
      # are deliberately excluded.
      restore_stock = @order.stock_restorable?

      refund = Stripe::Refund.create(payment_intent: @order.stripe_payment_intent_id)

      @order.transaction do
        @order.update!(refunded_cents: @order.total_cents, refunded_at: Time.current, status: "refunded")
        @order.restore_stock! if restore_stock
      end

      refund
    end
  end
end
