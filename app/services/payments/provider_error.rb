module Payments
  # Raised by Payments::Tabby / Payments::Tamara when the provider's API
  # returns an error or an unexpected/missing response shape. Deliberately
  # a plain StandardError, not rescued anywhere automatically — the caller
  # (CheckoutsController) decides what to show the customer, same as it
  # already does for Stripe::StripeError.
  class ProviderError < StandardError; end
end
