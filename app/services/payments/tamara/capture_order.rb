module Payments
  module Tamara
    # POST /payments/capture — the manual counterpart to Tamara's own 21-day
    # auto-capture. Tamara's own docs are blunt about why this matters:
    # "Orders NOT captured are NOT settled to your account!" — auto-capture
    # is a safety net for orders nobody remembers to capture, not a reason
    # to skip this deliberately.
    #
    # shipping_info (shipped_at + shipping_company) is required by Tamara's
    # own schema, and this app has no carrier/tracking field on Order yet —
    # shipping_company: "N/A" is Tamara's own example value for exactly
    # this case (see their Capture API reference), not a guess. Wired to
    # fire when an admin marks an order shipped (Admin::OrdersController
    # #update), the same real-world moment "capture" is meant to represent
    # — money should only be pulled once the order has actually gone out.
    class CaptureOrder
      def self.call(order:)
        new(order).call
      end

      def initialize(order)
        @order = order
      end

      def call
        Payments::Tamara.post("/payments/capture", {
          order_id: @order.tamara_order_id,
          total_amount: { amount: (@order.total_cents / 100.0).round(2), currency: "AED" },
          shipping_info: { shipped_at: Time.current.iso8601, shipping_company: "N/A" }
        })
      end
    end
  end
end
