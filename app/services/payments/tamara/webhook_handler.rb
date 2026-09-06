module Payments
  module Tamara
    # Dispatches verified Tamara webhook events (see TamaraWebhooksController,
    # which performs the actual JWT signature check). Same redelivery-safe
    # shape as Payments::WebhookHandler (Stripe) and
    # Payments::Tabby::WebhookHandler: every handler re-checks the order's
    # current status before mutating it.
    #
    # order_approved is the one Tamara docs mark mandatory; the others
    # (order_expired/order_declined/order_canceled/order_refunded/
    # order_captured) follow the same order_<status> naming pattern shown
    # for order_approved/order_authorised/order_captured in Tamara's own
    # webhook payload docs. Only order_approved (via the order_status
    # fallback below) and order_authorised have been independently
    # confirmed against a real, organically-delivered webhook; logged (not
    # raised) if an event type shows up unrecognized so a naming mismatch
    # fails safe instead of 500ing.
    class WebhookHandler
      # Confirmed live against a real, organically-delivered webhook (not a
      # self-administered curl): the per-order merchant_url.notification
      # callback — the one this app actually configures at checkout time,
      # see Payments::Tamara::CreateOrder — delivers a simpler payload with
      # no "event_type" key at all, only order_id/order_reference_id/
      # order_status/data. event_type only ever showed up in this app's
      # earlier self-administered tests, which were modeled on Tamara's
      # separate "Webhooks" payload docs — a different notification
      # channel (configured account-wide in Tamara's merchant dashboard,
      # not per-order) that this account has never actually been proven to
      # receive. Falling back to order_status here is what makes the
      # channel we actually get organic deliveries on work at all; without
      # it, a genuinely-authorised real order (confirmed via GET) stayed
      # "awaiting_payment" in our own DB forever, silently.
      EVENT_TYPE_BY_ORDER_STATUS = {
        "approved" => "order_approved",
        "authorised" => "order_authorised",
        "captured" => "order_captured",
        "fully_captured" => "order_captured",
        "partially_captured" => "order_captured",
        "declined" => "order_declined",
        "expired" => "order_expired",
        "canceled" => "order_canceled",
        "cancelled" => "order_canceled",
        "refunded" => "order_refunded",
        "fully_refunded" => "order_refunded",
        "partially_refunded" => "order_refunded"
      }.freeze

      def self.call(payload)
        new(payload).call
      end

      def initialize(payload)
        @payload = payload
      end

      def call
        event_type = @payload["event_type"].presence || EVENT_TYPE_BY_ORDER_STATUS[@payload["order_status"]]

        case event_type
        when "order_approved" then handle_approved
        # Tamara's own onboarding docs: "We now support Auto-authorisation!
        # ...the order status will move from New -> Approved -> Fully
        # Captured without you having to call the Authorisation API
        # explicitly" when it's enabled for a merchant account — meaning
        # order_authorised, not order_approved, can be the only success
        # webhook actually sent. Handled separately from handle_approved,
        # not merged into the same case branch: calling our own /authorise
        # a second time on an order Tamara already auto-authorised is
        # undocumented behavior (could plausibly error), so this instead
        # verifies via GET (same "never trust the webhook payload alone"
        # discipline as Payments::Tabby::WebhookHandler#handle_authorized)
        # and marks the order paid without re-calling /authorise.
        when "order_authorised" then handle_authorised
        when "order_captured" then nil # already marked paid at authorise time; informational only
        when "order_declined", "order_expired", "order_canceled" then handle_failed
        when "order_refunded" then handle_refunded
        else
          Rails.logger.info(
            "Tamara webhook: unhandled event_type #{@payload["event_type"].inspect} " \
            "(order_status=#{@payload["order_status"].inspect})"
          )
        end
      end

      private

      # "approved" means the customer's first payment succeeded — Tamara's
      # own docs say to call /orders/{id}/authorise upon receiving exactly
      # this event, and once authorised "you can consider the order paid."
      # Deliberately does NOT call capture here (see
      # Payments::Tamara::CreateOrder's own comment and this app's
      # docs/superpowers spec) — Tamara's capture endpoint requires real
      # shipping_company/shipped_at data this app doesn't collect yet, so
      # this relies on Tamara's own documented 21-day auto-capture instead
      # of a fragile half-built manual flow.
      def handle_approved
        order_id = @payload["order_id"]
        order = Order.find_by(tamara_order_id: order_id)
        unless order
          message = "Tamara webhook: no order found for order_id #{order_id}"
          Rails.logger.error(message)
          Sentry.capture_message(message, level: :error)
          return
        end

        payment_just_confirmed = false

        order.with_lock do
          next unless order.awaiting_payment?

          Payments::Tamara.post("/orders/#{order_id}/authorise", {})
          order.update!(status: "pending")
          payment_just_confirmed = true
        end

        if payment_just_confirmed
          OrderMailer.confirmation(order).deliver_later
          AdminMailer.new_order(order).deliver_later
        end
      rescue Payments::ProviderError => e
        Rails.logger.error("Tamara webhook: authorise failed for order #{order_id}: #{e.message}")
        Sentry.capture_exception(e)
      end

      # See the case statement's comment — this is order_authorised's own
      # path, not a re-run of handle_approved, specifically so a merchant
      # account with Tamara's auto-authorisation enabled never calls
      # POST /orders/{id}/authorise on an order Tamara already authorised
      # itself.
      def handle_authorised
        order_id = @payload["order_id"]
        order = Order.find_by(tamara_order_id: order_id)
        unless order
          message = "Tamara webhook: no order found for order_id #{order_id}"
          Rails.logger.error(message)
          Sentry.capture_message(message, level: :error)
          return
        end

        payment_just_confirmed = false

        order.with_lock do
          next unless order.awaiting_payment?

          verification = Payments::Tamara.get("/orders/#{order_id}")
          verified_status = verification["status"]
          Rails.logger.info(
            "Tamara webhook: GET /orders/#{order_id} verification returned status=#{verified_status.inspect} " \
            "(webhook itself said #{@payload["event_type"].inspect})"
          )

          next unless %w[authorised fully_captured partially_captured].include?(verified_status)

          order.update!(status: "pending")
          payment_just_confirmed = true
        end

        if payment_just_confirmed
          OrderMailer.confirmation(order).deliver_later
          AdminMailer.new_order(order).deliver_later
        end
      rescue Payments::ProviderError => e
        Rails.logger.error("Tamara webhook: verification failed for order #{order_id}: #{e.message}")
        Sentry.capture_exception(e)
      end

      def handle_failed
        order = Order.find_by(tamara_order_id: @payload["order_id"])
        return unless order

        order.with_lock do
          next unless order.awaiting_payment?

          order.restore_stock!
          order.update!(status: "cancelled")
        end
      end

      # Deliberately does NOT trust @payload["data"]["refunded_amount"] —
      # two different Tamara doc pages disagree on what that field even
      # means: the webhook payload docs call it a running total, but the
      # GET /orders/{id} docs show a refund *entry* uses "total_amount"
      # for its own amount, with "refunded_amount" meaning something else
      # entirely (how much of a specific *capture* has been refunded).
      # Genuinely unresolved without a real captured webhook to inspect.
      # Sidesteps the ambiguity the same way Payments::Tabby::
      # WebhookHandler#handle_authorized and this class's own
      # handle_authorised already do: never trust the webhook payload for
      # the actual number, verify via GET instead. The order's own
      # top-level refunded_amount there is unambiguous (confirmed
      # directly, live, against the real sandbox — not from a doc
      # summary) and is Tamara's own running total for the order, so
      # setting (not accumulating) is correct and naturally idempotent
      # against a redelivered webhook.
      def handle_refunded
        order_id = @payload["order_id"]
        order = Order.find_by(tamara_order_id: order_id)
        return unless order

        order.with_lock do
          next if order.refunded?

          verification = Payments::Tamara.get("/orders/#{order_id}")
          refunded_amount = verification.dig("refunded_amount", "amount")
          if refunded_amount.nil?
            message = "Tamara webhook: order_refunded for order_id #{order_id} — GET /orders/#{order_id} verification had no refunded_amount.amount: #{verification.inspect}"
            Rails.logger.error(message)
            Sentry.capture_message(message, level: :error)
            next
          end
          refunded_cents = (refunded_amount.to_f * 100).round
          next if refunded_cents <= order.refunded_cents

          fully_refunded = refunded_cents >= order.total_cents
          order.update!(
            refunded_cents: refunded_cents, refunded_at: Time.current,
            status: fully_refunded ? "refunded" : order.status
          )
          # Only a full refund means the order won't ship (or won't ship
          # the rest of it) — restoring stock for a partial refund would
          # incorrectly re-add units for an order that's still going out,
          # since a partial refund is ordinarily a price adjustment, not
          # a returned item.
          order.restore_stock! if fully_refunded && order.stock_restorable?
        end
      rescue Payments::ProviderError => e
        Rails.logger.error("Tamara webhook: refund verification failed for order #{order_id}: #{e.message}")
        Sentry.capture_exception(e)
      end
    end
  end
end
