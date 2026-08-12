class AddDeliveryAndWarrantyNotesToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :delivery_note, :string
    add_column :products, :warranty_note, :string
  end
end
