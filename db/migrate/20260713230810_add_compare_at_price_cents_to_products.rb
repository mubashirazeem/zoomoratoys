class AddCompareAtPriceCentsToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :compare_at_price_cents, :integer
  end
end
