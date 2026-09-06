# Deliberately does NOT inherit from ApplicationController — same reasoning
# as StripeWebhooksController/TabbyWebhooksController: an unauthenticated,
# machine-to-machine POST, not a real page view.
#
# Tamara signs notifications as a real HS256 JWT (tamaraToken), sent both
# as a query param and as an Authorization: Bearer header — decoding and
# verifying that signature (via the jwt gem, using TAMARA_NOTIFICATION_KEY
# as the HMAC secret) is the actual security boundary here, not just
# matching a plain string.
class TamaraWebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false

  def create
    unless verified_payload
      head :unauthorized
      return
    end

    payload = JSON.parse(request.body.read)
    Payments::Tamara::WebhookHandler.call(payload)
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  # Returns truthy only if the token's signature actually verifies against
  # our configured Notification Key — a forged or tampered token raises
  # inside JWT.decode and is caught here, never reaching the handler.
  #
  # Reads the query string directly via request.query_parameters, not
  # params[:tamaraToken] — touching params on a Content-Type: application/
  # json request makes Rails eagerly parse the whole body to build it, and
  # a malformed body then raises ActionDispatch::Http::Parameters::
  # ParseError right here, before #create's own JSON.parse + rescue
  # JSON::ParserError ever gets a chance to turn that into a clean 400.
  def verified_payload
    token = request.query_parameters["tamaraToken"].presence || request.headers["Authorization"].to_s.delete_prefix("Bearer ").presence
    return false if token.blank?

    secret = ENV["TAMARA_NOTIFICATION_KEY"]
    return false if secret.blank?

    JWT.decode(token, secret, true, algorithm: "HS256")
    true
  rescue JWT::DecodeError
    false
  end
end
