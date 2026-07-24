# frozen_string_literal: true

# A real, admin-defined product variant — e.g. {"Color" => "Racing Red",
# "Size" => "Standard"}. Option keys are free-form (same "Label: Value" text
# pattern as Product#specifications), not fixed to Color/Size/Material —
# different product types need different option sets (a trampoline might
# only vary by Size, a scooter by Color and Material).
class ProductVariant < ApplicationRecord
  belongs_to :product
  # A live cart reference, not order history (line_items has no variant
  # column — a sale is recorded against the Product, not this row) — a
  # deleted variant should simply disappear from any cart that has it,
  # same as Product's cart_items association. Without this, destroying a
  # variant currently in any cart raised a raw, unhandled
  # ActiveRecord::InvalidForeignKey (confirmed reproducible).
  has_many :cart_items, dependent: :destroy

  validates :sku, presence: true, uniqueness: true
  validates :options, presence: true
  validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Same virtual-attribute pattern as Product#price — admin types whole AED,
  # storage stays an integer. Blank clears the override (falls back to the
  # product's own price).
  def price
    price_cents && (price_cents / 100.0)
  end

  def price=(value)
    self.price_cents = value.present? ? (value.to_f * 100).round : nil
  end

  # The price actually charged — the variant's own override if set, else
  # the parent product's price. Never nil (product.price_cents is required).
  def effective_price_cents
    price_cents || product.price_cents
  end

  def in_stock?
    stock_quantity.to_i.positive?
  end

  # A variant has no independent stock_status — "in stock" is always
  # derived live from stock_quantity (#in_stock? above), so there's nothing
  # to keep in sync. Defined as a no-op so callers can treat Product/
  # ProductVariant polymorphically after a stock_quantity change (see
  # Order.create_from_cart!/#restore_stock!).
  def sync_stock_status!
  end

  def option_summary
    options.map { |label, value| "#{label}: #{value}" }.join(", ")
  end
end
