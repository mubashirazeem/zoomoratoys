class CreatePromotionalBanners < ActiveRecord::Migration[7.2]
  def change
    create_table :promotional_banners do |t|
      t.string :title, null: false
      t.text :description
      t.string :cta_label
      t.string :cta_url
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :promotional_banners, :position
    add_index :promotional_banners, :active
  end
end
