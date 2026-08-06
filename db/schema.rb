# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_08_05_234153) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "label"
    t.string "full_name", null: false
    t.string "phone", null: false
    t.string "address_line1", null: false
    t.string "address_line2"
    t.string "city", null: false
    t.string "emirate", null: false
    t.boolean "default_address", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "default_address"], name: "index_addresses_on_user_id_and_default_address"
    t.index ["user_id"], name: "index_addresses_on_user_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_admin_users_on_unlock_token", unique: true
  end

  create_table "blog_posts", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "excerpt", null: false
    t.text "body", null: false
    t.string "cover_image_key", null: false
    t.datetime "published_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_blog_posts_on_published_at"
    t.index ["slug"], name: "index_blog_posts_on_slug", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id", "product_variant_id"], name: "index_cart_items_on_cart_product_variant", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.index ["product_variant_id"], name: "index_cart_items_on_product_variant_id"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "user_id"
    t.string "guest_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "coupon_id"
    t.index ["coupon_id"], name: "index_carts_on_coupon_id"
    t.index ["guest_token"], name: "index_carts_on_guest_token", unique: true
    t.index ["user_id"], name: "index_carts_on_user_id", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.string "placeholder_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "contact_messages", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "subject", null: false
    t.text "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code", null: false
    t.string "discount_type", default: "percentage", null: false
    t.integer "discount_value", null: false
    t.boolean "active", default: true, null: false
    t.datetime "expires_at"
    t.integer "usage_limit"
    t.integer "times_used", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_coupon_id"
    t.string "stripe_promotion_code_id"
    t.index ["code"], name: "index_coupons_on_code", unique: true
  end

  create_table "line_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.integer "price_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_variant_id"
    t.index ["order_id"], name: "index_line_items_on_order_id"
    t.index ["product_id"], name: "index_line_items_on_product_id"
    t.index ["product_variant_id"], name: "index_line_items_on_product_variant_id"
  end

  create_table "newsletter_subscribers", force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_newsletter_subscribers_on_email", unique: true
  end

  create_table "order_number_counters", force: :cascade do |t|
    t.integer "next_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "order_number", null: false
    t.string "status", default: "pending", null: false
    t.integer "total_cents", null: false
    t.datetime "placed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "shipping_name", default: "", null: false
    t.string "shipping_phone", default: "", null: false
    t.string "shipping_address_line1", default: "", null: false
    t.string "shipping_address_line2"
    t.string "shipping_city", default: "", null: false
    t.string "shipping_emirate", default: "", null: false
    t.string "payment_method", default: "pay_on_delivery", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "gift_wrap_cents", default: 0, null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.string "stripe_invoice_id"
    t.integer "refunded_cents", default: 0, null: false
    t.datetime "refunded_at"
    t.integer "discount_cents", default: 0, null: false
    t.string "stripe_hosted_invoice_url"
    t.bigint "coupon_id"
    t.string "stripe_dispute_status"
    t.index ["coupon_id"], name: "index_orders_on_coupon_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["order_number"], name: "index_orders_on_order_number_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["placed_at"], name: "index_orders_on_placed_at"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["stripe_checkout_session_id"], name: "index_orders_on_stripe_checkout_session_id", unique: true
    t.index ["stripe_payment_intent_id"], name: "index_orders_on_stripe_payment_intent_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "sku", null: false
    t.jsonb "options", default: {}, null: false
    t.integer "price_cents"
    t.integer "stock_quantity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "((options ->> 'Color'::text))", name: "index_product_variants_on_color_option"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
  end

  create_table "product_views", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "viewer_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "viewer_token"], name: "index_product_views_on_product_id_and_viewer_token", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "price_cents", null: false
    t.string "sku", null: false
    t.string "stock_status", default: "in_stock", null: false
    t.boolean "featured", default: false, null: false
    t.integer "position", default: 0, null: false
    t.string "placeholder_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "best_seller", default: false, null: false
    t.integer "stock_quantity", default: 0, null: false
    t.jsonb "specifications", default: {}, null: false
    t.text "safety_notes"
    t.text "care_notes"
    t.integer "compare_at_price_cents"
    t.index ["best_seller"], name: "index_products_on_best_seller"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["created_at"], name: "index_products_on_created_at"
    t.index ["description"], name: "index_products_on_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["featured"], name: "index_products_on_featured"
    t.index ["name"], name: "index_products_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["position", "name"], name: "index_products_on_position_and_name"
    t.index ["price_cents"], name: "index_products_on_price_cents"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["sku"], name: "index_products_on_sku_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.index ["stock_status"], name: "index_products_on_stock_status"
  end

  create_table "promotional_banners", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "cta_label"
    t.string "cta_url"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_promotional_banners_on_active"
    t.index ["position"], name: "index_promotional_banners_on_position"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.integer "rating", null: false
    t.text "comment", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "created_at"], name: "index_reviews_on_product_id_and_created_at"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.index ["user_id", "product_id"], name: "index_reviews_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_customer_id"
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email"], name: "index_users_on_email_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["first_name"], name: "index_users_on_first_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["last_name"], name: "index_users_on_last_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_wishlist_items_on_product_id"
    t.index ["user_id", "product_id"], name: "index_wishlist_items_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_wishlist_items_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "users"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "product_variants"
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "coupons"
  add_foreign_key "carts", "users"
  add_foreign_key "line_items", "orders"
  add_foreign_key "line_items", "product_variants"
  add_foreign_key "line_items", "products"
  add_foreign_key "orders", "coupons"
  add_foreign_key "orders", "users"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_views", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "reviews", "products"
  add_foreign_key "reviews", "users"
  add_foreign_key "wishlist_items", "products"
  add_foreign_key "wishlist_items", "users"
end
