# Deliberately does NOT inherit from ApplicationController — same reasoning
# as StripeWebhooksController: this is an unauthenticated, machine-to-
# machine POST from Tabby's own infrastructure, not a real page view.
#
# Tabby's signing scheme (see docs.tabby.ai/api-reference/webhooks) is a
# custom header whose name/value the merchant chooses at registration time
# (see lib/tasks/tabby.rake's create_webhook task) — not HMAC over the
# payload. The security boundary here is that exact header value matching
# what only we and Tabby know, checked with a timing-safe comparison so a
# byte-by-byte response-time attack can't guess it.
class TabbyWebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false

  def create
    unless valid_signature?
      head :unauthorized
      return
    end

    payload = JSON.parse(request.body.read)
    result = Payments::Tabby::WebhookHandler.call(payload)
    # A non-200 here is deliberate for :order_not_found — Tabby retries a
    # non-200 response, which is exactly what's needed for the "webhook
    # arrives before your own order is saved" race (see WebhookHandler#call
    # and docs.tabby.ai/pay-in-4-custom-integration/webhooks). Acknowledging
    # with 200 when we can't match the payment yet would drop that event
    # for good instead of getting a retry once our own transaction commits.
    head(result == :order_not_found ? :not_found : :ok)
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def valid_signature?
    expected = ENV["TABBY_WEBHOOK_SECRET"]
    return false if expected.blank?

    received = request.headers["X-Tabby-Webhook-Secret"].to_s
    ActiveSupport::SecurityUtils.secure_compare(received, expected)
  end
end
