# frozen_string_literal: true

# Presentational cart for this frontend-only pass — there is no session or
# database-backed cart yet (see PROJECT_VISION.md non-goals). Shows a fixed
# demo set of real catalog products (@cart_products, loaded globally by
# ApplicationController#set_cart since the header's mini-cart drawer needs it
# on every page too) so the UI can be reviewed fully populated; quantity/
# remove/gift-wrap interactions are client-side only (see cart_controller.js).
# DEMO_ITEM_SLUGS is the single source of truth for "what's in the cart".
class CartsController < ApplicationController
  DEMO_ITEM_SLUGS = %w[trailblazer-junior-4x4 backyard-bounce-8ft].freeze
  GIFT_WRAP_CENTS = 1_500

  def show
    @gift_wrap_cents = GIFT_WRAP_CENTS
  end
end
