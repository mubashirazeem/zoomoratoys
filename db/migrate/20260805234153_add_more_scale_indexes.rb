# frozen_string_literal: true

# Follow-up to AddScaleIndexes — a production-readiness audit found four
# more columns that are filtered/sorted on with no supporting index.
class AddMoreScaleIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Product.newest_first (New Arrivals, Recently Viewed, "newest" shop
    # sort) — order(created_at: :desc) with nothing backing it.
    add_index :products, :created_at, algorithm: :concurrently

    # Payments::WebhookHandler#handle_refunded/#handle_dispute_updated look
    # up an order by this column on every refund/dispute webhook.
    add_index :orders, :stripe_payment_intent_id, algorithm: :concurrently

    # Admin::CustomersController#index sorts by this with no index.
    add_index :users, :created_at, algorithm: :concurrently

    # BlogPost.newest_first / .published both filter/sort on this.
    add_index :blog_posts, :published_at, algorithm: :concurrently

    # Product.with_variant_color filters on this jsonb expression directly.
    add_index :product_variants, "(options ->> 'Color')", name: "index_product_variants_on_color_option", algorithm: :concurrently
  end
end
