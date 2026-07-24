# frozen_string_literal: true

class WishlistItemsController < ApplicationController
  before_action :authenticate_user!

  # One idempotent endpoint rather than separate create/destroy actions —
  # the button on a product card/product page always says "toggle", so the
  # server-side action matches: add if absent, remove if present.
  def toggle
    product = Product.find_by!(slug: params[:product_id])
    existing = current_user.wishlist_items.find_by(product: product)

    if existing
      existing.destroy
      notice = "Removed from your wishlist."
    else
      current_user.wishlist_items.create!(product: product)
      notice = "Added to your wishlist."
    end

    redirect_back fallback_location: product_path(product), notice: notice
  rescue ActiveRecord::RecordInvalid
    # A double-click racing two requests for the same product — the unique
    # index already prevented a duplicate row; nothing further to do.
    redirect_back fallback_location: product_path(product), notice: "Added to your wishlist."
  end
end
