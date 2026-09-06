module Payments
  module Tamara
    # Voids an authorised-but-not-yet-captured order on Tamara's side — the
    # counterpart to relying on Tamara's own 21-day auto-capture instead of
    # calling Capture Order manually (see CreateOrder/WebhookHandler).
    # Called from Admin::OrdersController#update when an admin cancels an
    # order that's already past awaiting_payment (meaning Tamara considers
    # it authorised). Without this, cancelling here only updated our own
    # records — Tamara was never told, and would auto-capture the payment
    # anyway once the 21-day window closed on an order we'll never ship.
    class CancelOrder
      def self.call(order:)
        new(order).call
      end

      def initialize(order)
        @order = order
      end

      def call
        Payments::Tamara.post("/orders/#{@order.tamara_order_id}/cancel", {
          total_amount: { amount: format("%.2f", @order.total_cents / 100.0), currency: "AED" }
        })
      end
    end
  end
end
