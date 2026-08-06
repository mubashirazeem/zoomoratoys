# config/initializers/stripe.rb

# No explicit Stripe.api_version pin here deliberately — this account's
# default API version (set in the Stripe Dashboard) is used instead.
# Revisit once this integration has been live for a while and pinning a
# known-good version becomes valuable; guessing a specific dated version
# string here without verifying it's real would be worse than not pinning.
Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")

# Defaults (30s open / 80s read / 2 retries) are too generous for calls made
# from inside a DB transaction holding product/order row locks (see
# Payments::CreateCardOrder and Payments::WebhookHandler) — a slow Stripe
# response would hold those locks for minutes. Fail fast instead; a rescued
# Stripe::StripeError degrades far better than a multi-minute lock hold.
Stripe.open_timeout = 5
Stripe.read_timeout = 10
Stripe.max_network_retries = 1
