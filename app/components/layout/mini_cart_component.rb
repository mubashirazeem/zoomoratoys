# frozen_string_literal: true

# Slide-out mini-cart drawer, rendered once in the layout and opened from
# the header's cart icon on any page. Uses its own cart-drawer Stimulus
# controller (a DrawerControllerBase subclass, same open/close/focus-trap
# behavior as the mobile nav's nav-drawer controller, but a separate
# identifier so the two drawers' open state never collide).
#
# Presentational for this frontend-only pass: quantity/remove are client-
# side only (cart_controller.js), no session cart yet (see PROJECT_VISION.md
# non-goals and CartsController's doc comment).
class Layout::MiniCartComponent < ViewComponent::Base
  def initialize(products: [], suggested_products: [])
    @products = products
    @suggested_products = suggested_products
  end

  attr_reader :products, :suggested_products

  def subtotal_cents
    products.sum(&:price_cents)
  end

  def format_aed(cents)
    helpers.format_aed(cents)
  end
end
