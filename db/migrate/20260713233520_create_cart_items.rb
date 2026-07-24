class CreateCartItems < ActiveRecord::Migration[7.2]
  def change
    create_table :cart_items do |t|
      t.references :cart, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end
    add_index :cart_items, [ :cart_id, :product_id, :product_variant_id ], unique: true, name: "index_cart_items_on_cart_product_variant"
  end
end
