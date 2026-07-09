class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :price_cents, null: false
      t.string :sku, null: false
      t.string :stock_status, null: false, default: "in_stock"
      t.boolean :featured, null: false, default: false
      t.integer :position, null: false, default: 0
      t.string :placeholder_key, null: false

      t.timestamps
    end

    add_index :products, :slug, unique: true
    add_index :products, :sku, unique: true
    add_index :products, :featured
  end
end
