# frozen_string_literal: true

# Renders a price stored as integer AED cents (see DATABASE_GUIDELINES.md),
# in whichever currency the visitor has picked to display (see
# ApplicationHelper#format_price/#display_currency — the real charge stays
# AED regardless), with optional "compare at" strikethrough pricing for a
# future sale feature. Every product card/grid on the site renders through
# this one component, so it's also the one place that display conversion
# needs to be wired in for prices to change "everywhere."
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
    helpers.format_price(@price_cents)
  end

  def formatted_compare_at
    helpers.format_price(@compare_at_cents)
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
