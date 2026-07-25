# frozen_string_literal: true

# Real query against the `orders` table (see Order model), written by
# CheckoutsController at the end of a real checkout.
class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action -> { @robots_noindex = true }

  def index
    @orders = current_user.orders.newest_first
  end

  # Scoped to current_user, same as index — a customer can only ever look
  # up their own orders, never someone else's by guessing an id.
  def show
    @order = current_user.orders.includes(line_items: { product: { images_attachments: :blob } }).find(params[:id])
  end
end
