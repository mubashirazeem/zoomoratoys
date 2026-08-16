# frozen_string_literal: true

# Real cart page — @cart_items/@cart_item_count/@cart_subtotal_cents are
# already set globally by ApplicationController#set_cart (the header's
# mini-cart drawer needs them on every page too, not just here).
class CartsController < ApplicationController
  GIFT_WRAP_CENTS = 5_000
  EXPRESS_DELIVERY_CENTS = 10_000

  before_action -> { @robots_noindex = true }

  def show
    @gift_wrap_cents = GIFT_WRAP_CENTS
  end
end
