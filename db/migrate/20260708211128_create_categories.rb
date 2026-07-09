class CreateCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.string :placeholder_key, null: false

      t.timestamps
    end

    add_index :categories, :slug, unique: true
  end
end
