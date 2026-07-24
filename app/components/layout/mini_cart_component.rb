# frozen_string_literal: true

# Slide-out mini-cart drawer, rendered once in the layout and opened from
# the header's cart icon on any page. Uses its own cart-drawer Stimulus
# controller (a DrawerControllerBase subclass, same open/close/focus-trap
# behavior as the mobile nav's nav-drawer controller, but a separate
# identifier so the two drawers' open state never collide).
#
# Real cart items (see CartItem) — quantity/remove submit real requests to
# CartItemsController, same as the full /cart page.
class Layout::MiniCartComponent < ViewComponent::Base
  def initialize(cart_items: [], subtotal_cents: 0, suggested_products: [])
    @cart_items = cart_items
    @subtotal_cents = subtotal_cents
    @suggested_products = suggested_products
  end

  attr_reader :cart_items, :subtotal_cents, :suggested_products

  def format_aed(cents)
    helpers.format_aed(cents)
  end
end
