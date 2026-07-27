module Payments
  # Lets a customer start a fresh payment attempt for a card order that's
  # still awaiting_payment — the common real scenario being: they reached
  # Stripe's Checkout page, then closed the tab or hit back without paying.
  # Stock stays exactly as reserved by the original Order.create_from_cart!
  # call; this never touches stock or line items, only ever issues a
  # payment attempt against what's already reserved for this order.
  #
  # Reuses the order's existing Stripe Checkout Session if it's still open
  # (the common case — the customer only just navigated away, well within
  # Stripe's 24h default expiry) rather than always minting a new one. Only
  # falls back to creating a fresh session once the old one has genuinely
  # expired or been consumed.
  class ResumeCardOrder
    def self.call(order:, user:, success_url_for:, cancel_url:)
      existing_url = reusable_session_url(order)
      return existing_url if existing_url

      session = StripeCheckoutSessionBuilder.call(
        order: order, user: user, success_url: success_url_for.call(order), cancel_url: cancel_url
      )
      order.update!(stripe_checkout_session_id: session.id)
      session.url
    end

    def self.reusable_session_url(order)
      return nil if order.stripe_checkout_session_id.blank?

      session = Stripe::Checkout::Session.retrieve(order.stripe_checkout_session_id)
      session.url if session.status == "open"
    rescue Stripe::InvalidRequestError
      nil
    end
  end
end
