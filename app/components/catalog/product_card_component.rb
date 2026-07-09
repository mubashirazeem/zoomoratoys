# frozen_string_literal: true

# Receives a fully-loaded Product — never queries itself (see
# COMPONENT_GUIDELINES.md). The caller is responsible for eager-loading
# whatever the product needs.
#
# Badge / "sale" pricing / colour swatches below are PRESENTATIONAL
# placeholders for this frontend pass — derived deterministically from the
# product so the grid shows realistic variety, without inventing new database
# columns or business logic (a real store would drive these from inventory,
# promotions, and variants).
class Catalog::ProductCardComponent < ViewComponent::Base
  SALE_MULTIPLIER = 1.27
  SWATCH_COLORS = %w[#C01827 #0A0A0B #7E8189 #16748F #E85F66 #3D7A4A].freeze

  def initialize(product:)
    @product = product
  end

  attr_reader :product

  def sold_out?
    product.sold_out?
  end

  # nil, :sold_out, :sale, or :new — deterministic per product.
  def badge_variant
    return :sold_out if sold_out?

    case bucket(5)
    when 0 then :sale
    when 1 then :new
    end
  end

  def on_sale?
    badge_variant == :sale
  end

  # Placeholder "was" price shown struck-through on sale items.
  def compare_at_cents
    return unless on_sale?

    (product.price_cents * SALE_MULTIPLIER).round
  end

  def show_swatches?
    !sold_out? && bucket(2).zero?
  end

  # A short, deterministic row of colour dots + an overflow count.
  def swatches
    count = 3 + bucket(3)
    SWATCH_COLORS.first(count)
  end

  def swatch_overflow
    [bucket(4), 1].max
  end

  private

  # Stable 0..(n-1) bucket derived from the product's identity, so the same
  # product always renders the same badge/swatches across page loads.
  def bucket(n)
    (product.id || product.name.to_s.bytesize) % n
  end
end
