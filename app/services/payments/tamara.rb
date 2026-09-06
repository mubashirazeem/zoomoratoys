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

    def base_url
      ENV.fetch("TAMARA_BASE_URL", "https://api-sandbox.tamara.co")
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
        req["Authorization"] = "Bearer #{ENV.fetch('TAMARA_API_TOKEN')}"
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
