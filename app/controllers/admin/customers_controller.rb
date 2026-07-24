# frozen_string_literal: true

# Customers register themselves — no create/edit here, deliberately. Admin
# can view detail (including real order history) and remove an account.
class Admin::CustomersController < Admin::BaseController
  def index
    @customers = User.order(created_at: :desc)
    @customers = @customers.search(params[:q]) if params[:q].present?
    @customers = @customers.page(params[:page]).per(24)
    # Computed after pagination, not via a grouped/joined pagination query —
    # Kaminari's counting behaves unpredictably combined with GROUP BY.
    @order_counts = Order.where(user_id: @customers.map(&:id)).group(:user_id).count
  end

  def show
    @customer = User.find(params[:id])
    @orders = @customer.orders.newest_first
  end
end
