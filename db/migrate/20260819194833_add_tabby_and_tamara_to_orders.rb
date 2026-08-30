class AddTabbyAndTamaraToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :tabby_payment_id, :string
    add_column :orders, :tamara_order_id, :string
    add_index :orders, :tabby_payment_id, unique: true
    add_index :orders, :tamara_order_id, unique: true
  end
end
