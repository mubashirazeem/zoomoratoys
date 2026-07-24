# frozen_string_literal: true

# Real aggregation against actual Order/LineItem data — honestly empty/zero
# until checkout exists and starts creating real orders. No fabricated
# numbers standing in for a chart that doesn't have data yet.
class Admin::SalesReportsController < Admin::BaseController
  REVENUE_STATUSES = %w[processing shipped delivered].freeze

  def show
    @total_revenue_cents = Order.where(status: REVENUE_STATUSES).sum(:total_cents)
    @order_count_by_status = Order.group(:status).count
    # Grouped by product id (name is display-only, not unique — see
    # Product#validates :name) so two differently-priced products that
    # happen to share a name are never incorrectly merged into one row.
    @top_products = LineItem.joins(:product)
                             .group(:product_id, "products.name")
                             .sum(:quantity)
                             .sort_by { |(_id, _name), quantity| -quantity }
                             .first(10)
  end
end
