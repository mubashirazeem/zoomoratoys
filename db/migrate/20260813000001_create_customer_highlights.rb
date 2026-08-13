class CreateCustomerHighlights < ActiveRecord::Migration[7.2]
  def change
    create_table :customer_highlights do |t|
      t.string :customer_name, null: false
      t.text :quote, null: false
      t.integer :rating, null: false, default: 5
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :customer_highlights, :position
    add_index :customer_highlights, :active
  end
end
