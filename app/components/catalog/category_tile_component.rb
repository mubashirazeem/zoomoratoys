# frozen_string_literal: true

# A large, browsable category tile: full-bleed photo with a bold caption bar
# carrying the category name. The name is always real, visible text — never a
# bare image link with no accessible name (see UI_UX_GUIDELINES.md).
class Catalog::CategoryTileComponent < ViewComponent::Base
  # Short, display-friendly labels keyed by placeholder_key. Canonical source
  # for both these tiles and the header nav (which references this constant),
  # so the two never drift.
  SHORT_LABELS = {
    "bicycle" => "Ebike",
    "scooter" => "Cargo Scooters",
    "pool" => "Inflatables",
    "dirtbike" => "Dirt Bikes",
    "atv" => "ATVs & Quadbikes"
  }.freeze

  def initialize(category:)
    @category = category
  end

  attr_reader :category

  def url
    products_path(category: category.slug)
  end

  def label
    SHORT_LABELS.fetch(category.placeholder_key, category.name)
  end
end
