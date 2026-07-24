# frozen_string_literal: true

class CartItemsController < ApplicationController
  before_action :set_product, only: [ :create ]
  before_action :set_cart_item, only: [ :update, :destroy ]

  def create
    variant = find_variant

    if @product.has_variants? && variant.blank?
      return redirect_back fallback_location: product_path(@product),
        alert: "Please choose #{@product.variant_option_types.to_sentence} before adding this to your cart."
    end

    quantity = params[:quantity].presence&.to_i || 1
    quantity = 1 if quantity < 1

    cart = persisted_cart
    existing = cart.cart_items.find_by(product: @product, product_variant: variant)
    requested_total = quantity + (existing&.quantity || 0)
    available = (variant || @product).stock_quantity

    if requested_total > available
      return redirect_back fallback_location: product_path(@product), alert: stock_alert(@product, available)
    end

    if existing
      existing.update!(quantity: requested_total)
    else
      cart.cart_items.create!(product: @product, product_variant: variant, quantity: quantity)
    end

    if params[:buy_now].present?
      redirect_to checkout_path
    else
      redirect_back fallback_location: cart_path, notice: "Added to your cart."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: cart_path, alert: e.record.errors.full_messages.to_sentence
  end

  def update
    quantity = params[:quantity].presence&.to_i || 0

    if quantity < 1
      @cart_item.destroy
    else
      available = @cart_item.available_stock
      if quantity > available
        return redirect_to cart_path, alert: stock_alert(@cart_item.product, available)
      end

      @cart_item.update!(quantity: quantity)
    end

    redirect_to cart_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_to cart_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    @cart_item.destroy
    redirect_to cart_path, notice: "Removed from your cart."
  end

  private

  def set_product
    @product = Product.find_by!(slug: params[:product_id])
  end

  def find_variant
    return nil if params[:product_variant_id].blank?

    @product.product_variants.find(params[:product_variant_id])
  end

  def stock_alert(product, available)
    return "#{product.name} is out of stock." if available.zero?

    "Only #{available} #{available == 1 ? "is" : "are"} available of #{product.name}."
  end

  # No side-effecting persisted_cart here: a cart that isn't persisted yet
  # has no cart_items at all, so raising RecordNotFound is correct — no
  # need to (wastefully) create an empty Cart row just to fail the lookup.
  def set_cart_item
    raise ActiveRecord::RecordNotFound unless current_cart.persisted?

    @cart_item = current_cart.cart_items.find(params[:id])
  end
end
