class CreateAddresses < ActiveRecord::Migration[7.2]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :label
      t.string :full_name, null: false
      t.string :phone, null: false
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :city, null: false
      t.string :emirate, null: false
      t.boolean :default_address, null: false, default: false

      t.timestamps
    end
    add_index :addresses, [ :user_id, :default_address ]
  end
end
