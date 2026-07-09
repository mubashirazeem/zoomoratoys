# frozen_string_literal: true

# Renders a price stored as integer cents (see DATABASE_GUIDELINES.md) in
# AED, with optional "compare at" strikethrough pricing for a future sale
# feature. Formatting lives here — nowhere else in the app formats currency.
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
    format_cents(@price_cents)
  end

  def formatted_compare_at
    format_cents(@compare_at_cents)
  end

  def size_classes
    { sm: "text-body-sm", card: "text-[14px] font-semibold", base: "text-h3", lg: "text-h2" }.fetch(@size)
  end

  private

  # Deliberately hand-rolled rather than a Rails NumberHelper method: AED
  # display has no decimal places at this catalog's price points, and this
  # avoids depending on ActionView helper delegation working a particular
  # way inside a ViewComponent.
  def format_cents(cents)
    whole_units = (cents / 100).to_s
    grouped = whole_units.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
    "AED #{grouped}"
  end
end
