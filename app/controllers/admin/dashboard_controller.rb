# frozen_string_literal: true

class Admin::DashboardController < Admin::BaseController
  def show
    @product_count = Product.count
    @category_count = Category.count
    @customer_count = User.count
    @order_count = Order.count
    @pending_order_count = Order.pending.count
    @coupon_count = Coupon.count
  end
end
