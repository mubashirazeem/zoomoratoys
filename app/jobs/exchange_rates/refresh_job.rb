# frozen_string_literal: true

module ExchangeRates
  # Fetches the current AED->USD rate from a free, keyless endpoint and
  # records it via ExchangeRate.record! — see that model for why reads
  # never wait on this job directly (stale-while-revalidate: a page always
  # gets an instant answer, this just keeps that answer fresh in the
  # background). Never raises — a fetch failure just leaves the existing
  # (possibly stale) rate in place for the next request to keep serving;
  # the next stale check will simply try again.
  class RefreshJob < ApplicationJob
    SOURCE_URL = URI("https://open.er-api.com/v6/latest/AED")

    # The real AED/USD rate has sat at ~0.2723 for decades (AED is pegged to
    # USD at a fixed 3.6725) and isn't going anywhere — this band exists
    # purely as a corruption guard, not a realistic trading range. It
    # catches the failure modes that would otherwise silently wreck every
    # USD price on the site: a response shaped so `rate` comes back 0 or
    # nil-turned-into-0, a provider outage returning a placeholder like 1,
    # or the classic inverted-rate mistake (~3.67, i.e. AED-per-USD instead
    # of USD-per-AED) — any of those would still leave the real charge
    # untouched (Stripe never reads this value), but would show a badly
    # wrong "estimate" to every shopper until caught.
    PLAUSIBLE_RANGE = 0.1..0.5

    def perform
      response = Net::HTTP.start(SOURCE_URL.host, SOURCE_URL.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
        http.get(SOURCE_URL)
      end
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("ExchangeRates::RefreshJob: fetch failed with #{response.code}")
        return
      end

      rate = JSON.parse(response.body).dig("rates", "USD")
      unless rate.is_a?(Numeric) && PLAUSIBLE_RANGE.cover?(rate)
        Rails.logger.warn("ExchangeRates::RefreshJob: implausible or missing USD rate: #{rate.inspect}")
        return
      end

      ExchangeRate.record!(usd_per_aed: rate)
    rescue StandardError => e
      Rails.logger.warn("ExchangeRates::RefreshJob: #{e.class}: #{e.message}")
    end
  end
end
