# frozen_string_literal: true

# Always exactly one row — the latest known AED->USD rate. Backs
# ApplicationHelper#format_price's currency-converted display prices
# (product cards, cart, checkout summary — see PROJECT_VISION.md; the
# actual charge stays AED everywhere, this only ever affects what's shown).
#
# Reads never touch the network (see .current_usd_per_aed) — this is a
# stale-while-revalidate cache, not a live lookup: a page render always
# gets an instant answer (the last known rate, or a hardcoded fallback if
# none has ever been fetched), and a background ExchangeRates::RefreshJob
# is opportunistically enqueued whenever that answer is more than
# STALE_AFTER old. There's no cron/Sidekiq in this app — the refresh job
# runs on the same in-process ActiveJob adapter already relied on for
# OrderMailer/AdminMailer's deliver_later.
class ExchangeRate < ApplicationRecord
  # The real, permanent AED/USD peg (1 USD = 3.6725 AED, fixed by the UAE
  # Central Bank since 1997) — used only until the very first
  # ExchangeRates::RefreshJob completes, so a brand-new install never shows
  # a missing or zero USD price while that first fetch is in flight.
  FALLBACK_USD_PER_AED = BigDecimal("0.272294")

  STALE_AFTER = 12.hours

  def self.current_usd_per_aed
    row = first

    if row.nil?
      ExchangeRates::RefreshJob.perform_later
      return FALLBACK_USD_PER_AED
    end

    ExchangeRates::RefreshJob.perform_later if row.fetched_at < STALE_AFTER.ago
    row.usd_per_aed
  end

  # Called only by ExchangeRates::RefreshJob. Always exactly one row: a
  # fresh fetch replaces the existing rate rather than accumulating history
  # this app has no use for.
  #
  # create_or_find_by! (not first_or_initialize) is load-bearing here, not a
  # style choice: on a fresh install, every concurrent request that sees no
  # row yet enqueues its own RefreshJob (see .current_usd_per_aed), so
  # several can genuinely race to create "the first" row at once — this
  # actually happened during manual testing (5 rows landed in one dev DB
  # from a single browsing session). first_or_initialize has no protection
  # against that: two racing calls can each see no row, then each insert
  # one. create_or_find_by! is Rails' own documented answer to exactly this
  # race — it relies on the unique index on singleton_guard (see the
  # AddSingletonGuardToExchangeRates migration) to let the database itself
  # reject every insert after the first, and transparently falls back to
  # finding that row instead of raising.
  def self.record!(usd_per_aed:)
    row = create_or_find_by!(singleton_guard: 1) do |r|
      r.usd_per_aed = usd_per_aed
      r.fetched_at = Time.current
    end
    # The block above only runs on the create path (a brand-new row needs
    # usd_per_aed/fetched_at set just to satisfy their NOT NULL columns on
    # insert) — this unconditional update! is what actually applies the
    # fresh rate on the far more common path, where create_or_find_by!
    # instead found the row that already existed.
    row.update!(usd_per_aed: usd_per_aed, fetched_at: Time.current)
  end
end
