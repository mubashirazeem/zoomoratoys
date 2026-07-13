# frozen_string_literal: true

# Full storefront header: dismissable announcement bar, utility bar
# (phone/email), main bar (logo + search + account/wishlist/cart/currency),
# and a category-driven primary nav that wraps and condenses on scroll.
#
# Currency selection is a presentational placeholder for this frontend-only
# pass — there is no multi-currency support yet (see PROJECT_VISION.md
# non-goals). The account link reflects a real Devise session (see
# Users::RegistrationsController), the wishlist link opens the real (session-
# less, demo-data) wishlist page — see WishlistsController — and the cart
# icon opens the real (session-less, demo-data) mini-cart drawer — see
# Layout::MiniCartComponent and CartsController. Search submits to the shop
# page.
class Layout::SiteHeaderComponent < ViewComponent::Base
  def initialize(categories: [], category_products: {}, cart_item_count: 0, wishlist_item_count: 0, current_user: nil)
    @categories = categories
    @category_products = category_products
    @cart_item_count = cart_item_count
    @wishlist_item_count = wishlist_item_count
    @current_user = current_user
  end

  attr_reader :categories, :cart_item_count, :wishlist_item_count, :current_user

  def signed_in?
    current_user.present?
  end

  # Up to three products for a category's mega-menu column (empty if none).
  def products_for(category)
    @category_products.fetch(category.id, [])
  end

  def formatted_price(cents)
    helpers.format_aed(cents)
  end

  def nav_items
    [
      { label: "Home", url: root_path },
      { label: "Rentals", url: rentals_path },
      *category_nav_items,
      { label: "Blogs", url: blog_posts_path },
      { label: "About Us", url: about_path },
      { label: "Contact Us", url: contact_path }
    ]
  end

  private

  def category_nav_items
    categories.map do |category|
      {
        label: category.name,
        url: products_path(category: category.slug),
        category: category
      }
    end
  end
end
