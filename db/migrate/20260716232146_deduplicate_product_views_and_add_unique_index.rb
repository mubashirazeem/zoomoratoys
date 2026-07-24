# frozen_string_literal: true

# ProductView.record! used to be check-then-create with no DB constraint
# behind it — two genuinely concurrent requests from the same visitor
# (double-tab, retried request) could both pass the "does this exist?"
# check before either insert landed, creating two rows for what should be
# one idempotent "viewing now" record. This adds the real constraint the
# model now relies on (see ProductView#record!) — which first requires
# deduplicating whatever same-(product, viewer) rows already exist,
# keeping the most recent one.
class DeduplicateProductViewsAndAddUniqueIndex < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DELETE FROM product_views a
      USING product_views b
      WHERE a.product_id = b.product_id
        AND a.viewer_token = b.viewer_token
        AND a.id < b.id
    SQL

    remove_index :product_views, name: "idx_on_product_id_viewer_token_created_at_5f913aa103"
    remove_index :product_views, name: "index_product_views_on_product_id"
    add_index :product_views, [ :product_id, :viewer_token ], unique: true
  end

  def down
    remove_index :product_views, [ :product_id, :viewer_token ]
    add_index :product_views, :product_id
    add_index :product_views, [ :product_id, :viewer_token, :created_at ],
      name: "idx_on_product_id_viewer_token_created_at_5f913aa103"
  end
end
