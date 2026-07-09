# frozen_string_literal: true

# Full storefront header: dismissable announcement bar, utility bar
# (phone/email), main bar (logo + search + account/wishlist/cart/currency),
# and a category-driven primary nav that wraps and condenses on scroll.
#
# Account/wishlist/cart/currency are presentational placeholders for this
# frontend-only pass — there is no auth, cart, or multi-currency backend yet
# (see PROJECT_VISION.md non-goals). Search submits to the shop page.
class Layout::SiteHeaderComponent < ViewComponent::Base
  def initialize(categories: [])
    @categories = categories
  end

  attr_reader :categories

  def nav_items
    [
      { label: "Home", url: root_path },
      *category_nav_items,
      { label: "About", url: about_path },
      { label: "Contact", url: contact_path }
    ]
  end

  private

  def category_nav_items
    categories.map do |category|
      { label: Catalog::CategoryTileComponent::SHORT_LABELS.fetch(category.placeholder_key, category.name), url: products_path(category: category.slug) }
    end
  end
end
