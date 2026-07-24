class CreateProductViews < ActiveRecord::Migration[7.2]
  def change
    create_table :product_views do |t|
      t.references :product, null: false, foreign_key: true
      t.string :viewer_token, null: false

      t.timestamps
    end
    add_index :product_views, [ :product_id, :viewer_token, :created_at ]
  end
end
