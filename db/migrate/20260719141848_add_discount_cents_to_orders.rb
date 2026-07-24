class AddDiscountCentsToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :discount_cents, :integer, null: false, default: 0
  end
end
