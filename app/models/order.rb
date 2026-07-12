# frozen_string_literal: true

# Real schema, no real writer yet: nothing creates an Order until checkout/
# Stripe lands (see PROJECT_VISION.md non-goals). Order History
# (OrdersController#index) queries this honestly — it shows an empty state
# for every user today, not fabricated demo rows, unlike the Cart/Wishlist
# placeholder pattern.
class Order < ApplicationRecord
  belongs_to :user
  has_many :line_items, dependent: :destroy

  enum :status, { pending: "pending", processing: "processing", shipped: "shipped",
                   delivered: "delivered", cancelled: "cancelled" },
       default: "pending", validate: true

  validates :order_number, presence: true, uniqueness: true
  validates :total_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :placed_at, presence: true

  scope :newest_first, -> { order(placed_at: :desc) }
end
