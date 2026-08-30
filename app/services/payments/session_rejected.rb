module Payments
  # Raised when a provider's own checkout-session-creation call comes back
  # with a legitimate "rejected" verdict (Tabby: status == "rejected"), as
  # opposed to Payments::ProviderError, which means the API call itself
  # failed or returned something malformed.
  #
  # A rejection is a normal business outcome, not a technical failure — per
  # Tabby's own testing checklist: "don't log it as a failure or fire
  # alerts." Callers must rescue this separately from ProviderError so it
  # never reaches Rails.logger.error/Sentry, and show the carried message
  # to the customer instead of redirecting (there is no web_url to
  # redirect to on a reject).
  class SessionRejected < StandardError; end
end
