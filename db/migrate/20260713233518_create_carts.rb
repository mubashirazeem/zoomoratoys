class CreateCarts < ActiveRecord::Migration[7.2]
  def change
    create_table :carts do |t|
      t.references :user, foreign_key: true, index: { unique: true }
      t.string :guest_token

      t.timestamps
    end
    add_index :carts, :guest_token, unique: true
  end
end
