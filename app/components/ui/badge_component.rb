# frozen_string_literal: true

# Small status label. Color alone is never the only signal — the word is
# always shown (see ACCESSIBILITY_GUIDELINES.md).
class Ui::BadgeComponent < ViewComponent::Base
  # Flat color fills with a soft, colored drop shadow — not a gradient/inset-
  # highlight bevel, which reads as dated skeuomorphism (see the card CSS
  # comment in the layout head for the fuller rationale).
  VARIANTS = {
    sale: { label: "Sale", classes: "bg-red-600 text-white shadow-[0_4px_14px_-4px_rgba(192,24,39,.5)]" },
    new: { label: "New", classes: "bg-ink-950 text-white shadow-[0_4px_14px_-4px_rgba(10,10,11,.4)]" },
    sold_out: { label: "Sold Out", classes: "bg-grey-200 text-grey-700" },
    preorder: { label: "Preorder", classes: "bg-white text-ink-950 border border-grey-300" }
  }.freeze

  def initialize(variant:, label: nil)
    raise ArgumentError, "unknown badge variant: #{variant.inspect}" unless VARIANTS.key?(variant)

    @variant = variant
    @label = label || VARIANTS.fetch(variant)[:label]
  end

  def classes
    VARIANTS.fetch(@variant)[:classes]
  end

  attr_reader :label
end
