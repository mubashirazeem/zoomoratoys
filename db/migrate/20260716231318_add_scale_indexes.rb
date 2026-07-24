# frozen_string_literal: true

# Indexes for columns that are actually filtered/sorted on today but have
# no index behind them — fine at today's row counts, a full table scan
# once these tables have real (millions-of-rows) production volume.
class AddScaleIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Admin order status filter (Admin::OrdersController#index) and the
    # sales report's revenue/status aggregates (Admin::SalesReportsController).
    add_index :orders, :status, algorithm: :concurrently

    # Order.newest_first (order(placed_at: :desc)) is the *default*,
    # unfiltered sort for the admin order list — sorts the entire table
    # on every page load without this.
    add_index :orders, :placed_at, algorithm: :concurrently

    # Shop page availability filter (ProductsController#index).
    add_index :products, :stock_status, algorithm: :concurrently

    # Shop page price range filter and price_asc/price_desc sort.
    add_index :products, :price_cents, algorithm: :concurrently

    # Product.ordered (order(:position, :name)) — the default sort for
    # both the customer Shop page and the admin product picker contexts.
    add_index :products, [ :position, :name ], algorithm: :concurrently
  end
end
