module Payments
  module Tabby
    # Lets a customer start a fresh payment attempt for a Tabby order that's
    # still awaiting_payment — the common real scenario being: they reached
    # Tabby's hosted checkout page, then cancelled, failed, or closed the
    # tab without paying. Stock stays exactly as reserved by the original
    # Order.create_from_cart! call; this never touches stock or line items,
    # only ever issues a new payment session against what's already
    # reserved for this order.
    #
    # Unlike Payments::ResumeCardOrder, this never reuses a previous
    # session — Tabby's own testing checklist requires every payment
    # attempt to get its own disposable session, so this always mints a
    # brand-new one via SessionBuilder and overwrites the order's
    # tabby_payment_id with the new one.
    class ResumeOrder
      def self.call(order:, user:, success_url_for:, cancel_url:, failure_url:)
        close_previous_payment(order)

        session = SessionBuilder.call(
          order: order, user: user,
          success_url: success_url_for.call(order), cancel_url: cancel_url, failure_url: failure_url
        )

        # Same distinction as Payments::Tabby::CreateOrder — a reject is a
        # business outcome, not a failure. The order stays exactly as it
        # was (still awaiting_payment, stock still reserved); only this one
        # resume attempt didn't produce a session.
        raise Payments::SessionRejected, session[:message] if session[:rejected]

        order.update!(tabby_payment_id: session[:payment_id])
        session[:web_url]
      end

      # The scenario this guards against: our webhook's capture attempt
      # failed (network issue, timeout the retry also lost — see
      # WebhookHandler#capture_with_retry) but the payment itself really
      # was authorized on Tabby's side. Resuming here mints a brand-new,
      # completely independent session/payment (never reused, per
      # SessionBuilder's own docs) — without this, the OLD payment would
      # just sit there AUTHORIZED and uncaptured indefinitely: not
      # reflected in our order at all, and never released back to the
      # customer's credit either. Only AUTHORIZED is ever closed here — a
      # payment still at CREATED never held anything to release, and one
      # already CLOSED/REJECTED/EXPIRED has nothing left to do. A failure
      # to close is logged, not fatal — the customer getting a working new
      # session to actually pay with matters more than tidying up the old
      # one immediately, and it's still safe to close later (e.g. by hand)
      # since it was never captured.
      def self.close_previous_payment(order)
        return if order.tabby_payment_id.blank?

        status = Payments::Tabby.get("/api/v2/payments/#{order.tabby_payment_id}")["status"]
        Payments::Tabby.close(payment_id: order.tabby_payment_id) if status == "AUTHORIZED"
      rescue Payments::ProviderError => e
        Rails.logger.warn("Tabby resume: couldn't close previous payment #{order.tabby_payment_id} for order #{order.order_number} (#{e.message}) — proceeding with a new session anyway")
      end
    end
  end
end
