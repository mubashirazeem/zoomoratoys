# config/initializers/stripe.rb

# No explicit Stripe.api_version pin here deliberately — this account's
# default API version (set in the Stripe Dashboard) is used instead.
# Revisit once this integration has been live for a while and pinning a
# known-good version becomes valuable; guessing a specific dated version
# string here without verifying it's real would be worse than not pinning.
Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
