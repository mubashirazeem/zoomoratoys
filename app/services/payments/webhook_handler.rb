module Payments
  # Dispatches verified Stripe webhook events (see StripeWebhooksController,
  # which performs the actual signature verification — this class only ever
  # receives an already-authenticated Stripe::Event). Stripe redelivers
  # webhooks at-least-once, so every handler here is written to be safe to
  # run twice on the same event: each one re-checks the order's current
  # status before mutating it, rather than assuming this is the first (or
  # only) delivery.
  class WebhookHandler
    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      case @event.type
      when "checkout.session.completed", "checkout.session.async_payment_succeeded" then handle_completed
      when "checkout.session.expired", "checkout.session.async_payment_failed" then handle_expired
      when "charge.refunded" then handle_refunded
      when "charge.dispute.created", "charge.dispute.closed" then handle_dispute_updated
      end
    end

    private

    # checkout.session.completed fires for *every* Checkout Session that
    # reaches Stripe's success step — including delayed/async payment
    # methods (bank transfers etc.) where the money hasn't actually cleared
    # yet. Stripe's own integration docs call this out explicitly: check
    # payment_status, don't assume "completed" means "paid". A delayed
    # method that's still pending here resolves later via
    # checkout.session.async_payment_succeeded (routed to this same method,
    # this time with payment_status: "paid") or .async_payment_failed
    # (routed to handle_expired, same as a naturally expired session).
    def handle_completed
      session = @event.data.object
      return unless session.payment_status == "paid"

      order = Order.find_by(stripe_checkout_session_id: session.id)

      unless order
        Rails.logger.error("Stripe webhook: no order found for checkout session #{session.id}")
        return
      end

      # with_lock row-locks the order for the check-then-update below —
      # Stripe documents that webhook deliveries can occasionally arrive as
      # near-simultaneous duplicates, and without the lock two concurrent
      # deliveries could both see awaiting_payment? true before either
      # commits.
      order.with_lock do
        next unless order.awaiting_payment?

        order.update!(
          status: "pending",
          stripe_payment_intent_id: session.payment_intent,
          stripe_invoice_id: session.invoice,
          stripe_hosted_invoice_url: hosted_invoice_url_for(session.invoice)
        )
        # Redemption is counted here, not at order creation, to match
        # Stripe's own promotion-code redemption timing (a PromotionCode's
        # max_redemptions is consumed on checkout completion, not session
        # creation) — and because the awaiting_payment? guard above already
        # makes this run exactly once per order, redelivered events can't
        # double-count it.
        order.coupon&.increment!(:times_used)
      end
    end

    # session.invoice on the webhook payload is only ever the bare invoice
    # id, never expanded — the customer-facing hosted_invoice_url (Stripe's
    # own no-login-required receipt page, e.g. invoice.stripe.com/i/...)
    # needs its own retrieve call. Best-effort and rescued deliberately: an
    # order actually being paid must never fail to confirm just because this
    # one supplementary convenience link couldn't be fetched.
    def hosted_invoice_url_for(invoice_id)
      return nil if invoice_id.blank?

      Stripe::Invoice.retrieve(invoice_id).hosted_invoice_url
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe webhook: failed to fetch hosted_invoice_url for invoice #{invoice_id}: #{e.message}")
      nil
    end

    # Shared by checkout.session.expired (a session nobody ever paid, timed
    # out after Stripe's default 24h) and checkout.session.async_payment_failed
    # (a delayed payment method that did eventually resolve, just to a
    # failure) — both mean the same thing for us: this order was never
    # actually paid and its reserved stock needs to go back on sale.
    #
    # with_lock row-locks the order for the check-then-update — same
    # concurrent-redelivery reasoning as handle_completed above. Order#
    # restore_stock! has no idempotency guard of its own (see Task 3), so
    # the awaiting_payment? check inside the lock is what makes a
    # redelivered event safe: the second delivery finds the order already
    # moved to cancelled and no-ops instead of double-restoring stock.
    def handle_expired
      session = @event.data.object
      order = Order.find_by(stripe_checkout_session_id: session.id)
      return unless order

      order.with_lock do
        next unless order.awaiting_payment?

        order.restore_stock!
        order.update!(status: "cancelled")
      end
    end

    # charge.refunded fires on *every* refund against a charge, not only a
    # full one — amount_refunded is the cumulative total refunded so far,
    # which can be less than the order's total. charge.refunded (the
    # boolean) is Stripe's own authoritative signal for "fully refunded";
    # trusting amount_refunded alone without checking it would mark a
    # partially-refunded order (e.g. a goodwill AED 50 refund issued
    # straight from the Stripe Dashboard, bypassing Payments::RefundIssuer
    # entirely) as fully refunded and hand all of its stock back to sale,
    # even though the customer still has the items.
    #
    # order.with_lock (not a plain transaction) row-locks the order for the
    # duration of this check-then-update — Stripe explicitly documents that
    # webhook deliveries can occasionally arrive as near-simultaneous
    # duplicates, and without the lock two concurrent deliveries could both
    # read already_refunded as false before either commits, double-restoring
    # stock. already_refunded/restore_stock are still captured *before* the
    # update, since that update itself flips the order to "refunded" (which
    # would make a status check taken afterward always say "already
    # refunded, skip").
    def handle_refunded
      charge = @event.data.object
      order = Order.find_by(stripe_payment_intent_id: charge.payment_intent)
      return unless order

      order.with_lock do
        if charge.refunded
          already_refunded = order.refunded?
          restore_stock = order.stock_restorable?

          order.update!(refunded_cents: charge.amount_refunded, refunded_at: Time.current, status: "refunded")
          order.restore_stock! if restore_stock && !already_refunded
        else
          order.update!(refunded_cents: charge.amount_refunded)
        end
      end
    end

    # A dispute is the bank pulling money back on the cardholder's say-so —
    # it happens entirely outside Zoomora's control, and without this the
    # order would keep showing "Paid"/"Processing" with zero indication
    # anything is wrong. Deliberately doesn't auto-cancel, auto-refund, or
    # restore stock: a dispute can still be won by submitting evidence, so
    # only recording Stripe's own dispute.status (needs_response,
    # under_review, won, lost, ...) and surfacing it to the admin is safe;
    # any of those other actions would be presuming an outcome that hasn't
    # happened yet.
    def handle_dispute_updated
      dispute = @event.data.object
      order = Order.find_by(stripe_payment_intent_id: dispute.payment_intent)
      return unless order

      order.update!(stripe_dispute_status: dispute.status)
    end
  end
end
