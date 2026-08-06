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
      refund = Stripe::Refund.create(payment_intent: @order.stripe_payment_intent_id)

      # Stripe::Refund.create triggers a charge.refunded webhook almost
      # immediately, which Payments::WebhookHandler#handle_refunded may
      # process concurrently with this method — with_lock plus a fresh
      # refunded?/stock_restorable? read *inside* the lock (not captured
      # before the API call) is what stops both paths from restoring the
      # same order's stock twice, same reasoning as the webhook handler.
      @order.with_lock do
        already_refunded = @order.refunded?
        restore_stock = @order.stock_restorable?

        @order.update!(refunded_cents: @order.total_cents, refunded_at: Time.current, status: "refunded")
        @order.restore_stock! if restore_stock && !already_refunded
      end

      refund
    end
  end
end
