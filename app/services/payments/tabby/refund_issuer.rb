module Payments
  module Tabby
    # Mirrors Payments::RefundIssuer (Stripe) — full refunds only (see that
    # class's own non-goals note), same with_lock + already-refunded/
    # stock-restorable-read-inside-the-lock reasoning to stay race-safe.
    #
    # One real difference from Stripe: a Tabby refund is only ever
    # initiated from here — there's no separate dashboard/webhook actor
    # that could race this method the way Stripe's charge.refunded webhook
    # can race Payments::RefundIssuer, so there's no equivalent handler in
    # Payments::Tabby::WebhookHandler to guard against (Tabby reports a
    # refund via a non-empty refunds[] on an ordinary "closed" webhook,
    # which is already a no-op there).
    #
    # reference_id is "#{order_number}-refund", not the bare order_number
    # the capture already used — Tabby's own guidance is that every
    # capture and refund carries its own unique reference_id derived from
    # the order, not that the two operations share one.
    class RefundIssuer
      def self.call(order:)
        new(order).call
      end

      def initialize(order)
        @order = order
      end

      def call
        Payments::Tabby.refund(
          payment_id: @order.tabby_payment_id,
          amount_cents: @order.total_cents,
          reference_id: "#{@order.order_number}-refund"
        )

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
