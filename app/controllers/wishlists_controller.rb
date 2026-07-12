# frozen_string_literal: true

# Presentational wishlist for this frontend-only pass — no session or
# database-backed wishlist yet (same placeholder boundary as CartsController,
# see PROJECT_VISION.md non-goals). Shows a fixed demo set of real catalog
# products so the UI can be reviewed fully populated; removing an item is
# client-side only (see wishlist_controller.js). DEMO_ITEM_SLUGS is the
# single source of truth — ApplicationController reads its size for the
# header badge.
class WishlistsController < ApplicationController
  DEMO_ITEM_SLUGS = %w[kidling-foldable-scooter ridgecrest-110-youth-atv fort-horizon-climbing-frame].freeze

  def show
    @wishlist_products = Product.includes(:category).where(slug: DEMO_ITEM_SLUGS)
  end
end
