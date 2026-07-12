# frozen_string_literal: true

# A large, browsable category tile: full-bleed photo with a bold caption bar
# carrying the category name. The name is always real, visible text — never a
# bare image link with no accessible name (see UI_UX_GUIDELINES.md).
class Catalog::CategoryTileComponent < ViewComponent::Base
  def initialize(category:)
    @category = category
  end

  attr_reader :category

  def url
    products_path(category: category.slug)
  end

  # Category names are already short, nav-ready display text (e.g. "Cargo
  # Scooters", "Ride-Ons") — used directly rather than through a
  # placeholder_key-keyed lookup, which broke once multiple categories
  # started sharing a placeholder_key/photo (e.g. Scooters and Cargo
  # Scooters both use "scooter" — a keyed lookup can't tell them apart).
  def label
    category.name
  end
end
