# frozen_string_literal: true

# A real cart — belongs to either a signed-in User or an anonymous guest
# (identified by a signed cookie token, see CartsController), never both at
# once. A guest's cart is merged into their User cart the moment they sign
# in (see Cart.merge_guest_into_user!).
class Cart < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :coupon, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  validates :guest_token, uniqueness: true, allow_nil: true
  validate :has_user_or_guest_token

  def total_cents
    cart_items.sum(&:line_total_cents)
  end

  # Real, live discount preview only — not yet applied at Checkout/Order
  # (explicit decision: real coupon redemption at checkout is deferred
  # until Stripe Checkout is integrated, which will apply promotion codes
  # itself; see PROJECT_VISION.md). Returns 0 if the coupon has since
  # expired/been deactivated/hit its usage limit, rather than erroring.
  def discount_cents
    return 0 unless coupon&.redeemable?

    raw_discount = coupon.percentage? ? (total_cents * coupon.discount_value / 100.0).round : coupon.discount_value * 100
    [ raw_discount, total_cents ].min
  end

  def total_after_discount_cents
    total_cents - discount_cents
  end

  def item_count
    cart_items.sum(:quantity)
  end

  def empty?
    cart_items.none?
  end

  # Folds a guest cart's items into the now-signed-in user's cart, then
  # discards the guest cart — called right after Devise sign-in. Matching
  # (product, variant) lines add quantities together rather than duplicating.
  def self.merge_guest_into_user!(guest_token:, user:)
    guest_cart = find_by(guest_token: guest_token)
    return if guest_cart.blank?

    user_cart = find_or_create_by!(user: user)
    guest_cart.cart_items.each do |guest_item|
      existing = user_cart.cart_items.find_by(product_id: guest_item.product_id, product_variant_id: guest_item.product_variant_id)
      if existing
        existing.update!(quantity: existing.quantity + guest_item.quantity)
      else
        guest_item.update!(cart: user_cart)
      end
    end

    # Without this, guest_cart's `cart_items` association is still holding
    # the (now-reassigned) items in memory from the loop above — dependent:
    # destroy would reuse that stale cache and destroy those same rows by
    # id, wiping out the very items just moved to user_cart. Resetting
    # forces a fresh, empty re-query before the destroy.
    guest_cart.cart_items.reset
    guest_cart.destroy
  end

  private

  def has_user_or_guest_token
    errors.add(:base, "must belong to either a user or a guest") if user_id.blank? && guest_token.blank?
  end
end
