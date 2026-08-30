module Payments
  # Thin, dependency-free HTTP client for Tabby's own direct API (not
  # routed through a payment orchestrator like checkout.com) — same
  # Net::HTTP-only approach already used for ExchangeRates::RefreshJob,
  # rather than adding a gem for two endpoints. UAE-region base URL
  # (api.tabby.ai) — Tabby uses a separate api.tabby.sa for KSA merchants,
  # not applicable here.
  #
  # A note for any future code that reads a GET /payments/{id} response's
  # captures[] or refunds[] arrays: Tabby's own docs are explicit that
  # array position carries no meaning — find a specific entry (the latest
  # one, a particular reference_id, whatever's needed) by its created_at
  # or reference_id field, never by [0]/.first/.last. Everything in this
  # codebase today only ever checks these arrays for emptiness (see
  # Payments::Tabby::WebhookHandler#capture_with_retry and its sibling
  # check before capturing at all) — genuinely position-independent — so
  # there's nothing to fix yet, just something to keep true as this grows.
  module Tabby
    module_function

    BASE_URL = "https://api.tabby.ai".freeze

    def post(path, body, headers: {}, timeout: 10)
      request(Net::HTTP::Post, path, body, headers, timeout)
    end

    def get(path)
      request(Net::HTTP::Get, path, nil)
    end

    # Best-practice per Tabby's own docs: a full capture right after the
    # webhook verifies the payment is authorized — see
    # Payments::Tabby::WebhookHandler. reference_id doubles as an
    # idempotency key, so a redelivered webhook that captures again is a
    # safe no-op rather than a double charge.
    def capture(payment_id:, amount_cents:, reference_id:)
      post("/api/v2/payments/#{payment_id}/captures", {
        amount: format("%.2f", amount_cents / 100.0),
        reference_id: reference_id
      })
    end

    # Same shape as capture, different endpoint — see
    # Payments::Tabby::RefundIssuer. reference_id must be its own unique
    # value, not the capture's, per Tabby's own "every capture and refund
    # carries a unique reference_id derived from your order" guidance.
    def refund(payment_id:, amount_cents:, reference_id:)
      post("/api/v2/payments/#{payment_id}/refunds", {
        amount: format("%.2f", amount_cents / 100.0),
        reference_id: reference_id
      })
    end

    # Releases an authorized-but-uncaptured amount without capturing it —
    # Tabby's own docs: "If an order is fully cancelled, please close the
    # payment without capturing it." See Payments::Tabby::ResumeOrder,
    # which is the one caller: it supersedes an old, still-open payment
    # with a brand-new disposable session (per "sessions are disposable"),
    # so the old one has to be explicitly released or it's just left
    # holding the customer's credit for nothing.
    def close(payment_id:)
      post("/api/v2/payments/#{payment_id}/close", {})
    end

    # Net::HTTP raises its own exceptions (timeout, DNS failure, connection
    # refused, TLS failure) separately from returning an HTTP error response
    # — both are "Tabby didn't work" from every caller's point of view, so
    # both become Payments::ProviderError. Without this, a network failure
    # (as opposed to an HTTP error status) would skip both callers' rescue
    # Payments::ProviderError entirely: CheckoutsController#create's
    # friendly "couldn't start your payment" redirect, and
    # WebhookHandler#handle_authorized's "leave the order awaiting_payment,
    # don't crash the webhook request" handling.
    NETWORK_ERRORS = [
      Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError,
      Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError
    ].freeze

    def request(http_method_class, path, body, headers = {}, timeout = 10)
      uri = URI("#{BASE_URL}#{path}")

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: timeout, read_timeout: timeout) do |http|
        req = http_method_class.new(uri)
        req["Authorization"] = "Bearer #{ENV.fetch('TABBY_SECRET_KEY')}"
        req["Content-Type"] = "application/json"
        headers.each { |key, value| req[key] = value }
        req.body = body.to_json if body
        http.request(req)
      end

      parsed = safe_parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        raise Payments::ProviderError, "Tabby API error (#{response.code}) on #{path}: #{parsed["error"] || response.body}"
      end

      parsed
    rescue *NETWORK_ERRORS => e
      raise Payments::ProviderError, "Tabby API network error on #{path}: #{e.class}: #{e.message}"
    end

    def safe_parse(body)
      body.present? ? JSON.parse(body) : {}
    rescue JSON::ParserError
      {}
    end
  end
end
