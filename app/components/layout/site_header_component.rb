# frozen_string_literal: true

# Full storefront header: dismissable announcement bar, utility bar
# (phone/email), main bar (logo + search + account/wishlist/cart/currency),
# and a category-driven primary nav that wraps and condenses on scroll.
#
# Account/wishlist/cart/currency are presentational placeholders for this
# frontend-only pass — there is no auth, cart, or multi-currency backend yet
# (see PROJECT_VISION.md non-goals). Search submits to the shop page.
class Layout::SiteHeaderComponent < ViewComponent::Base
  def initialize(categories: [], category_products: {})
    @categories = categories
    @category_products = category_products
  end

  attr_reader :categories

  # Up to three products for a category's mega-menu column (empty if none).
  def products_for(category)
    @category_products.fetch(category.id, [])
  end

  # AED price with thousands separators. Hand-rolled because ActionView's
  # number_with_delimiter isn't reliably available inside a ViewComponent
  # (same reason Ui::PriceComponent formats its own currency).
  def formatted_price(cents)
    grouped = (cents / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    "AED #{grouped}"
  end

  def nav_items
    [
      { label: "Home", url: root_path },
      { label: "Rentals", url: rentals_path },
      *category_nav_items,
      { label: "Blogs", url: blog_posts_path },
      { label: "About", url: about_path },
      { label: "Contact", url: contact_path }
    ]
  end

  private

  def category_nav_items
    categories.map do |category|
      {
        label: Catalog::CategoryTileComponent::SHORT_LABELS.fetch(category.placeholder_key, category.name),
        url: products_path(category: category.slug),
        category: category
      }
    end
  end
end
