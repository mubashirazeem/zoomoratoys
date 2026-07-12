# frozen_string_literal: true

class CreateReviews < ActiveRecord::Migration[7.2]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment, null: false
      t.timestamps
    end
    add_index :reviews, [ :product_id, :created_at ]
    add_index :reviews, [ :user_id, :product_id ], unique: true
  end
end
