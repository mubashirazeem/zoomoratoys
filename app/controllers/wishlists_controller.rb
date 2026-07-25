# frozen_string_literal: true

# Real, per-user wishlist — requires sign-in, same as Account/Orders
# (OrdersController). A wishlist that doesn't survive across visits/devices
# isn't a real wishlist, and that requires an account to persist against.
class WishlistsController < ApplicationController
  before_action :authenticate_user!
  before_action -> { @robots_noindex = true }

  def show
    @wishlist_items = current_user.wishlist_items.includes(product: { images_attachments: :blob }).order(created_at: :desc)
  end
end
