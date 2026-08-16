class AddGiftWrapNameAndDeliveryToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :gift_wrap_name, :string
    add_column :orders, :delivery_method, :string, default: "standard", null: false
    add_column :orders, :delivery_fee_cents, :integer, default: 0, null: false
  end
end
