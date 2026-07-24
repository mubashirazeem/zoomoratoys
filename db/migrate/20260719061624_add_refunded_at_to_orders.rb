class AddRefundedAtToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :refunded_at, :datetime
  end
end
