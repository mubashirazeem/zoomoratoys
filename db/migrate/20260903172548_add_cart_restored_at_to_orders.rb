class AddCartRestoredAtToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :cart_restored_at, :datetime
  end
end
