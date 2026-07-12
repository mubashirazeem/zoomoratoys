# frozen_string_literal: true

# Deterministic-per-product variant selector (color/size/material) — same
# "real UI, no variants backend yet" pattern as ProductCardComponent's
# swatches: every option is a genuine, selectable control (Stimulus-driven,
# not decorative — see variant_selector_controller.js), but which options
# exist is derived from the product's identity rather than a real Variant
# model. Selecting an option updates this component's own displayed state
# only — it doesn't feed Add to Cart, which has no backend of its own
# either yet (see PROJECT_VISION.md non-goals).
class Catalog::ProductVariantsComponent < ViewComponent::Base
  COLORS = [
    { name: "Racing Red", hex: "#C01827" },
    { name: "Midnight Black", hex: "#0A0A0B" },
    { name: "Storm Grey", hex: "#7E8189" },
    { name: "Ocean Teal", hex: "#16748F" },
    { name: "Coral", hex: "#E85F66" },
    { name: "Forest Green", hex: "#3D7A4A" }
  ].freeze
  SIZES = %w[Standard Large XL].freeze
  MATERIALS = [ "Steel Frame", "Aluminum Frame", "Reinforced Poly" ].freeze

  def initialize(product:)
    @product = product
  end

  attr_reader :product

  def colors
    COLORS.first(3 + bucket(3, 1))
  end

  def sizes
    SIZES.first(2 + bucket(2, 2))
  end

  def materials
    MATERIALS.first(2 + bucket(2, 3))
  end

  private

  # Stable per-product bucket, offset by a seed so color/size/material don't
  # all land on the same count for a given product.
  def bucket(n, seed)
    ((product.id || product.name.to_s.bytesize) + seed) % n
  end
end
