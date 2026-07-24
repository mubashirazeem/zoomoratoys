# frozen_string_literal: true

# Receives a fully-loaded Product — never queries itself (see
# COMPONENT_GUIDELINES.md). The caller is responsible for eager-loading
# whatever the product needs.
#
# Sale badge/pricing are real, driven by Product#compare_at_price_cents (an
# admin-set genuine "was" price). Add to Cart and the wishlist heart are both
# real, server-persisted actions (CartItemsController/WishlistItemsController)
# — not client-side-only decoration.
class Catalog::ProductCardComponent < ViewComponent::Base
  # No real "new arrival" cutoff is defined anywhere in the app yet (the
  # homepage's New Arrivals rail is rank-based — the 8 newest — not
  # threshold-based), so this badge stays a deterministic placeholder until
  # that's decided. Real sale detection above takes priority over it.
  NEW_BUCKET = 5

  # wishlisted/signed_in must both be passed by the caller (from
  # ApplicationController's globally-computed @wishlisted_product_ids and
  # Devise's user_signed_in?) — never computed here per-card, which would be
  # an N+1 query on every page that renders a grid of these (Shop, homepage
  # rails, Related Products), and calling Devise's helpers directly from a
  # component breaks in isolated component tests (no Warden middleware
  # present outside a real request). See COMPONENT_GUIDELINES.md.
  def initialize(product:, wishlisted: false, signed_in: false)
    @product = product
    @wishlisted = wishlisted
    @signed_in = signed_in
  end

  attr_reader :product

  def sold_out?
    product.out_of_stock?
  end

  def on_sale?
    product.on_sale?
  end

  # nil, :sold_out, :sale, or :new.
  def badge_variant
    return :sold_out if sold_out?
    return :sale if on_sale?

    :new if bucket(NEW_BUCKET) == 1
  end

  def compare_at_cents
    product.compare_at_price_cents
  end

  def discount_percent
    product.discount_percent
  end

  def has_variants?
    product.has_variants?
  end

  def signed_in?
    @signed_in
  end

  def wishlisted?
    @wishlisted
  end

  private

  # Stable 0..(n-1) bucket derived from the product's identity, so the same
  # product always renders the same badge for a given product.
  def bucket(n)
    (product.id || product.name.to_s.bytesize) % n
  end
end
