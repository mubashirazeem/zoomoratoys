class AddProductVariantToLineItems < ActiveRecord::Migration[7.2]
  def change
    add_reference :line_items, :product_variant, null: true, foreign_key: true
  end
end
