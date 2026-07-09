class AddBestSellerToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :best_seller, :boolean, null: false, default: false
    add_index :products, :best_seller
  end
end
