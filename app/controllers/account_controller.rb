# frozen_string_literal: true

# Dashboard hub for a signed-in customer — the first authenticate_user!-gated
# controller in the app. Links out to Order History, Wishlist, and Devise's
# own account-settings edit form rather than duplicating any of them here.
class AccountController < ApplicationController
  before_action :authenticate_user!

  def show
    @order_count = current_user.orders.count
  end
end
