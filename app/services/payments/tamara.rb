module Payments
  # Thin, dependency-free HTTP client for Tamara's direct API — same
  # Net::HTTP-only approach as Payments::Tabby. Tamara's sandbox and
  # production environments are entirely different hostnames (unlike
  # Tabby, where one host serves both and the API key alone decides), so
  # this defaults to the safe choice — sandbox — unless TAMARA_BASE_URL is
  # explicitly set to the production host. Getting this wrong the unsafe
  # direction (accidentally live) is far worse than the safe direction
  # (accidentally sandbox), hence the default.
  module Tamara
    module_function

    PRODUCTION_BASE_URL = "https://api.tamara.co".freeze

    def base_url
      ENV.fetch("TAMARA_BASE_URL", "https://api-sandbox.tamara.co")
    end

    # True only when pointed at Tamara's real production API host — the one
    # signal that distinguishes "live Tamara" from "sandbox Tamara running
    # on a production deploy for QA". Drives widget_script_url's CDN host.
    def production?
      base_url == PRODUCTION_BASE_URL
    end

    # Whether Tamara may be surfaced at all on this environment — the
    # checkout option AND the on-site widget. dev/staging: always (sandbox
    # is the correct target there, and Tamara QA runs on staging).
    # production: only once real production credentials are in place —
    # never show a sandbox key on the live site (Tamara asked for exactly
    # this, 2026-09-10: "restrict sandbox testing to staging only").
    def available?
      !Rails.env.production? || production?
    end

    # Tamara's on-site "Tamara Summary" widget script — sandbox and
    # production are served from *different* CDN hosts (same path), and the
    # per-merchant merchant_widget_config a public key resolves against
    # only exists on the host that matches the key's environment. Loading
    # the production script with a sandbox key is exactly what makes
    # merchant_widget_config 404 (Tamara's own diagnosis, 2026-09-10), so
    # this follows base_url. Path confirmed live: cdn-sandbox.tamara.co
    # uses "widget-v2", not the "widget/v2" a support email suggested.
    def widget_script_url
      host = production? ? "https://cdn.tamara.co" : "https://cdn-sandbox.tamara.co"
      "#{host}/widget-v2/tamara-widget.js"
    end

    def post(path, body, timeout: 10)
      request(Net::HTTP::Post, path, body, timeout)
    end

    def get(path)
      request(Net::HTTP::Get, path, nil)
    end

    # See Payments::Tabby::NETWORK_ERRORS for why this is needed: without
    # it, a timeout/DNS/TLS failure (as opposed to an HTTP error response)
    # would skip both callers' rescue Payments::ProviderError — the
    # checkout controller's friendly error redirect and
    # WebhookHandler#handle_approved's "leave the order awaiting_payment,
    # don't crash the webhook request" handling.
    NETWORK_ERRORS = [
      Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError,
      Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError
    ].freeze

    def request(http_method_class, path, body, timeout = 10)
      uri = URI("#{base_url}#{path}")

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: timeout, read_timeout: timeout) do |http|
        req = http_method_class.new(uri)
        # ENV[] (not ENV.fetch) deliberately — a missing token must still
        # produce a real HTTP response from Tamara (a 401, wrapped below
        # into Payments::ProviderError, which every caller already
        # rescues), not a raw, unrescued KeyError. CheckEligibility runs
        # unconditionally on every checkout page load regardless of
        # payment method, so an unrescued exception here would 500 the
        # whole checkout page for every customer, not just ones using
        # Tamara — a real risk found by tracing this path the moment
        # production briefly had no Tamara credentials configured at all.
        req["Authorization"] = "Bearer #{ENV['TAMARA_API_TOKEN']}"
        req["Content-Type"] = "application/json"
        req.body = body.to_json if body
        http.request(req)
      end

      parsed = safe_parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        raise Payments::ProviderError, "Tamara API error (#{response.code}) on #{path}: #{parsed["message"] || response.body}"
      end

      parsed
    rescue *NETWORK_ERRORS => e
      raise Payments::ProviderError, "Tamara API network error on #{path}: #{e.class}: #{e.message}"
    end

    def safe_parse(body)
      body.present? ? JSON.parse(body) : {}
    rescue JSON::ParserError
      {}
    end
  end
end
