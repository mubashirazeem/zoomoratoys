class AddCheckoutFieldsToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :shipping_name, :string, null: false, default: ""
    add_column :orders, :shipping_phone, :string, null: false, default: ""
    add_column :orders, :shipping_address_line1, :string, null: false, default: ""
    add_column :orders, :shipping_address_line2, :string
    add_column :orders, :shipping_city, :string, null: false, default: ""
    add_column :orders, :shipping_emirate, :string, null: false, default: ""
    add_column :orders, :payment_method, :string, null: false, default: "pay_on_delivery"
    add_column :orders, :subtotal_cents, :integer, null: false, default: 0
    add_column :orders, :gift_wrap_cents, :integer, null: false, default: 0
  end
end
