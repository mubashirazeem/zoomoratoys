# frozen_string_literal: true

# Real query against the `orders` table (see Order model) — not a demo-data
# placeholder like CartsController/WishlistsController. Nothing creates an
# Order yet (checkout/Stripe isn't built), so this honestly renders an empty
# state for every user today rather than showing fabricated order history.
class OrdersController < ApplicationController
  before_action :authenticate_user!

  def index
    @orders = current_user.orders.newest_first
  end
end
