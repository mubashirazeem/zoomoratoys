# frozen_string_literal: true

# Real coupon apply/remove, at the Cart level only — a live discount
# preview, not yet wired into Order/Checkout. Explicit decision: real
# redemption at checkout is deferred until Stripe Checkout is integrated,
# which will apply promotion codes itself; see PROJECT_VISION.md.
class CartCouponsController < ApplicationController
  def create
    coupon = Coupon.find_by(code: params[:code].to_s.strip.upcase)

    if coupon.nil? || !coupon.redeemable?
      redirect_to cart_path, alert: "That coupon code isn't valid."
    else
      persisted_cart.update!(coupon: coupon)
      redirect_to cart_path, notice: "Coupon applied."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to cart_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    persisted_cart.update!(coupon: nil) if current_cart.persisted?
    redirect_to cart_path, notice: "Coupon removed."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to cart_path, alert: e.record.errors.full_messages.to_sentence
  end
end
