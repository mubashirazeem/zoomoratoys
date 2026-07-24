# frozen_string_literal: true

# Real inventory tracking (stock_quantity) and real per-product
# specifications (specifications, label => value), both admin-editable —
# replacing the hardcoded generic spec table on the product page. See
# DEVELOPMENT_PROGRESS.md.
class AddInventoryAndSpecificationsToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :stock_quantity, :integer, null: false, default: 0
    add_column :products, :specifications, :jsonb, null: false, default: {}
  end
end
