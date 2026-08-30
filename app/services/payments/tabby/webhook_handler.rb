module Payments
  module Tabby
    # Dispatches verified Tabby webhook events (see TabbyWebhooksController,
    # which performs the actual signature check — this class only ever
    # receives an already-authenticated payload). Written to be safe to run
    # twice on the same event, same as Payments::WebhookHandler (Stripe):
    # every handler re-checks the order's current status before mutating it.
    class WebhookHandler
      def self.call(payload)
        new(payload).call
      end

      def initialize(payload)
        @payload = payload
      end

      # Returns :order_not_found when the payload's payment id doesn't match
      # any order yet, :processed otherwise (including every case where
      # there was legitimately nothing to do — an ignorable status, a
      # redelivered event, a capture failure already logged/alerted).
      # TabbyWebhooksController uses this distinction to answer Tabby with
      # a non-200 only for :order_not_found — see "Handling Edge Cases" at
      # docs.tabby.ai/pay-in-4-custom-integration/webhooks: "the webhook can
      # arrive before your own order is saved... if your handler looks up
      # the order, finds nothing, and still acknowledges with 200, that
      # event is gone for good." Tabby retries a non-200 for a while, which
      # is exactly enough time for our own checkout transaction to commit.
      def call
        case @payload["status"]
        when "authorized" then handle_authorized
        when "closed" then :processed # a capture confirmation, not a trigger — see handle_authorized
        when "rejected", "expired" then handle_failed
        else :processed
        end
      end

      private

      # "you can consider the order paid" the instant Tabby reports
      # authorized — this is the same trust point Stripe's
      # checkout.session.completed (payment_status: "paid") represents.
      # Tabby's own best practice is a full capture immediately after this
      # verification, so that's done here too, inside the same lock: if the
      # capture call itself fails, the order is deliberately left
      # awaiting_payment rather than marked paid, so it can be retried
      # (Tabby allows capturing an authorized payment for up to 21 days)
      # instead of silently treating an uncaptured authorization as a sale.
      def handle_authorized
        payment_id = @payload["id"]
        order = Order.find_by(tabby_payment_id: payment_id)
        return :order_not_found unless order

        payment_just_confirmed = false

        order.with_lock do
          next unless order.awaiting_payment?

          # Tabby's own testing checklist requires this: don't capture off
          # the webhook payload alone — call GET /payments/{id} and only
          # capture if it independently confirms AUTHORIZED (uppercase;
          # the webhook's "authorized" is lowercase, a different string).
          verification = Payments::Tabby.get("/api/v2/payments/#{payment_id}")
          verified_status = verification["status"]
          Rails.logger.info(
            "Tabby webhook: GET /api/v2/payments/#{payment_id} verification returned " \
            "status=#{verified_status.inspect}, captures=#{Array(verification["captures"]).size} " \
            "(webhook itself said #{@payload["status"].inspect})"
          )

          # "Statuses only move forward" (same doc, "Handling Edge Cases"):
          # a closed event can be delivered before its own authorized one —
          # webhook delivery order isn't guaranteed. Treating only
          # AUTHORIZED as good enough would leave this order stuck
          # awaiting_payment forever in that ordering, even though the
          # payment is genuinely done. CLOSED means "already fully
          # captured," which is at least as final as AUTHORIZED here.
          next unless %w[AUTHORIZED CLOSED].include?(verified_status)

          # "A capture confirmation is not a request to capture" (same
          # section): only call our own capture if Tabby doesn't already
          # show one for this payment — covers both the CLOSED-already
          # case above and a redelivered authorized event racing a capture
          # already in flight.
          capture_with_retry(payment_id, order) if Array(verification["captures"]).empty?

          order.update!(status: "pending")
          payment_just_confirmed = true
        end

        if payment_just_confirmed
          OrderMailer.confirmation(order).deliver_later
          AdminMailer.new_order(order).deliver_later
        end

        :processed
      rescue Payments::ProviderError => e
        Rails.logger.error("Tabby webhook: capture failed for payment #{payment_id}: #{e.message}")
        Sentry.capture_exception(e)
        :processed
      end

      # "A capture timeout is not a failure" (same "Handling Edge Cases"
      # doc): a timeout only means we never saw the response — the capture
      # may have landed anyway. Re-checking via GET before retrying, with
      # the same reference_id either way, is what makes the retry itself
      # safe: Tabby dedupes on reference_id, so replaying it can't create
      # a second capture even if the first attempt actually succeeded
      # server-side. Any failure here (including the re-check itself)
      # propagates to handle_authorized's own rescue, same as a first-try
      # failure would.
      def capture_with_retry(payment_id, order)
        Payments::Tabby.capture(payment_id: payment_id, amount_cents: order.total_cents, reference_id: order.order_number)
      rescue Payments::ProviderError => e
        Rails.logger.warn("Tabby webhook: capture attempt failed for payment #{payment_id} (#{e.message}); re-checking before retry")
        still_uncaptured = Array(Payments::Tabby.get("/api/v2/payments/#{payment_id}")["captures"]).empty?
        return unless still_uncaptured # it actually landed despite the timeout — nothing more to do

        Payments::Tabby.capture(payment_id: payment_id, amount_cents: order.total_cents, reference_id: order.order_number)
      end

      # rejected: the customer never completed payment. expired: nobody
      # finished the flow in time. Both mean the same thing for us as a
      # Stripe checkout.session.expired — this order was never paid and its
      # reserved stock needs to go back on sale.
      def handle_failed
        order = Order.find_by(tabby_payment_id: @payload["id"])
        return :order_not_found unless order

        order.with_lock do
          next unless order.awaiting_payment?

          order.restore_stock!
          order.update!(status: "cancelled")
        end

        :processed
      end
    end
  end
end
