# frozen_string_literal: true

# Real variant selector: option types/values are whatever the admin actually
# defined for this product via Admin::ProductVariantsController — replaced
# the old deterministic-per-product-id Color/Size/Material fakery (see
# DEVELOPMENT_PROGRESS.md). Renders nothing if the product has no real
# variants defined yet, rather than fabricating options.
class Catalog::ProductVariantsComponent < ViewComponent::Base
  def initialize(product:)
    @product = product
  end

  attr_reader :product

  def render?
    product.has_variants?
  end

  def option_types
    product.variant_option_types
  end

  def option_values(option_type)
    product.variant_option_values(option_type)
  end

  # Serialized for the Stimulus controller — the single source of truth it
  # uses client-side to find the matching variant (real price/SKU/stock)
  # for whatever combination of options is currently selected.
  def variants_json
    product.product_variants.map do |variant|
      {
        id: variant.id,
        options: variant.options,
        price_cents: variant.effective_price_cents,
        sku: variant.sku,
        stock_quantity: variant.stock_quantity
      }
    end.to_json
  end

  def default_variant
    product.product_variants.first
  end
end
