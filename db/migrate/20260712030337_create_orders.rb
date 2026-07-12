# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :order_number, null: false
      t.string :status, null: false, default: "pending"
      t.integer :total_cents, null: false
      t.datetime :placed_at, null: false
      t.timestamps
    end
    add_index :orders, :order_number, unique: true

    create_table :line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :price_cents, null: false
      t.timestamps
    end
  end
end
