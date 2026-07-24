# frozen_string_literal: true

class CreateCoupons < ActiveRecord::Migration[7.2]
  def change
    create_table :coupons do |t|
      t.string :code, null: false
      t.string :discount_type, null: false, default: "percentage"
      t.integer :discount_value, null: false
      t.boolean :active, null: false, default: true
      t.datetime :expires_at
      t.integer :usage_limit
      t.integer :times_used, null: false, default: 0
      t.timestamps
    end
    add_index :coupons, :code, unique: true
  end
end
