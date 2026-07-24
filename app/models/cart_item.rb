# frozen_string_literal: true

class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :variant_belongs_to_product
  validate :variant_required_when_product_has_variants

  # Snapshot-free by design, unlike LineItem: a cart is a live shopping list,
  # not a receipt — it should always reflect the product's current price.
  # (LineItem, created at checkout, is the point where price gets frozen.)
  def unit_price_cents
    product_variant&.effective_price_cents || product.price_cents
  end

  def line_total_cents
    unit_price_cents * quantity
  end

  # The real, current stock backing this line — the variant's own count if
  # one was chosen, else the parent product's. Live, not a snapshot: stock
  # can change after something's added to a cart (someone else buys the
  # last unit), which is exactly what #stock_shortfall? below checks for.
  def available_stock
    (product_variant || product).stock_quantity
  end

  def stock_shortfall?
    quantity > available_stock
  end

  private

  def variant_belongs_to_product
    return if product_variant.blank? || product.blank?

    errors.add(:product_variant, "must belong to the selected product") if product_variant.product_id != product_id
  end

  def variant_required_when_product_has_variants
    return if product.blank?

    errors.add(:product_variant, "must be selected for this product") if product.has_variants? && product_variant.blank?
  end
end
