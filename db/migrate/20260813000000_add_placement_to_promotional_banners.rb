class AddPlacementToPromotionalBanners < ActiveRecord::Migration[7.2]
  def change
    # Every existing banner keeps rendering exactly where it already does
    # (between New Arrivals and Explore Categories) — the default matches
    # current behavior so this never requires a data backfill.
    add_column :promotional_banners, :placement, :string, null: false, default: "after_new_arrivals"
    add_index :promotional_banners, :placement
  end
end
