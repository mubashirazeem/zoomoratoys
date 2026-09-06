module Payments
  module Tamara
    # Full refunds only (see Payments::RefundIssuer's own non-goals note —
    # same restriction applies here). Uses Tamara's "Simplified Refund"
    # endpoint (POST /payments/simplified-refund/{order_id}) rather than
    # the older /payments/refund, which requires a capture_id — Simplified
    # Refund works directly against the order_id instead, so it doesn't
    # matter whether that particular capture's id was ever recorded here
    # (see Payments::Tamara::CaptureOrder, which does now call Capture
    # explicitly when an order ships, rather than relying solely on
    # Tamara's 21-day auto-capture fallback).
    #
    # Same with_lock + already-refunded/stock-restorable-read-inside-the-
    # lock race guard as Payments::RefundIssuer (Stripe) — necessary here
    # (unlike Payments::Tabby::RefundIssuer) because Tamara can also
    # report a refund asynchronously via an order_refunded webhook
    # (Payments::Tamara::WebhookHandler#handle_refunded), which could run
    # concurrently with this method.
    class RefundIssuer
      def self.call(order:)
        new(order).call
      end

      def initialize(order)
        @order = order
      end

      def call
        Payments::Tamara.post("/payments/simplified-refund/#{@order.tamara_order_id}", {
          total_amount: { amount: (@order.total_cents / 100.0).round(2), currency: "AED" },
          comment: "Refund for Zoomora order #{@order.order_number}",
          merchant_refund_id: "#{@order.order_number}-refund"
        })

        just_refunded = false

        @order.with_lock do
          already_refunded = @order.refunded?
          restore_stock = @order.stock_restorable?

          @order.update!(refunded_cents: @order.total_cents, refunded_at: Time.current, status: "refunded")
          @order.restore_stock! if restore_stock && !already_refunded
          just_refunded = !already_refunded
        end

        OrderMailer.refunded(@order).deliver_later if just_refunded
      end
    end
  end
end
