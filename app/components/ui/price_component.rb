# frozen_string_literal: true

# Renders a price stored as integer cents (see DATABASE_GUIDELINES.md) in
# AED, with optional "compare at" strikethrough pricing for a future sale
# feature. Formatting itself lives in ApplicationHelper#format_aed — the one
# place in the app that formats currency; every component reaches it via
# `helpers.format_aed` so they can never drift out of sync with each other.
class Ui::PriceComponent < ViewComponent::Base
  def initialize(price_cents:, compare_at_cents: nil, size: :base)
    @price_cents = price_cents
    @compare_at_cents = compare_at_cents
    @size = size
  end

  def on_sale?
    @compare_at_cents.present? && @compare_at_cents > @price_cents
  end

  def formatted_price
    helpers.format_aed(@price_cents)
  end

  def formatted_compare_at
    helpers.format_aed(@compare_at_cents)
  end

  def size_classes
    { sm: "text-body-sm", card: "text-[16px] font-bold", base: "text-h3", lg: "text-h2" }.fetch(@size)
  end

  # On a card, a discounted price turns brand-red to contrast the grey struck
  # original (the standard marketplace deal cue); a regular price stays dark.
  # Every non-card context keeps the near-black body/heading ink.
  def color_class
    return "text-ink-950" unless @size == :card

    on_sale? ? "text-red-600" : "text-ink-950"
  end
end
