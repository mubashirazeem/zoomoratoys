# Deliberately does NOT inherit from ApplicationController — that base
# class runs before_actions meant for real customer page views (nav
# category queries, cart lookups, guest-cart merging) that make no sense
# for an unauthenticated, machine-to-machine POST from Stripe's own
# infrastructure. The real security boundary here is the cryptographic
# request signature, not a Rails session.
class StripeWebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false

  def create
    event = Stripe::Webhook.construct_event(
      request.body.read, request.headers["Stripe-Signature"], ENV.fetch("STRIPE_WEBHOOK_SECRET")
    )
    Payments::WebhookHandler.call(event)
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end
end
