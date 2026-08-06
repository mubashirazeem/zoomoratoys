# frozen_string_literal: true

# Real coupon apply/remove, reachable from both the cart page and the
# checkout page (see carts/_coupon_form partial, rendered on both) —
# redirect_back sends the customer back to whichever one they applied it
# from. Actually wired into Order/Checkout: Payments::CreateCardOrder
# reads current_cart.coupon and passes its promotion code to Stripe.
class CartCouponsController < ApplicationController
  def create
    coupon = Coupon.find_by(code: params[:code].to_s.strip.upcase)

    if coupon.nil?
      redirect_back fallback_location: cart_path, alert: "That coupon code isn't valid."
    elsif coupon.expired?
      redirect_back fallback_location: cart_path, alert: "That coupon code has expired."
    elsif coupon.usage_limit_reached?
      redirect_back fallback_location: cart_path, alert: "That coupon code has reached its usage limit."
    elsif !coupon.active? || !stripe_promotion_code_active?(coupon)
      redirect_back fallback_location: cart_path, alert: "That coupon code isn't valid."
    else
      persisted_cart.update!(coupon: coupon)
      redirect_back fallback_location: cart_path, notice: "Coupon applied."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: cart_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    persisted_cart.update!(coupon: nil) if current_cart.persisted?
    redirect_back fallback_location: cart_path, notice: "Coupon removed."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: cart_path, alert: e.record.errors.full_messages.to_sentence
  end

  private

  # Our local `active`/expires_at/usage_limit fields can drift from Stripe's
  # own copy of the promotion code — e.g. Payments::CouponSync's Stripe call
  # failing after the local record already saved (see
  # Admin::CouponsController#sync_to_stripe), or someone deactivating the
  # code directly in the Stripe Dashboard. Checking live here means a
  # customer sees "That coupon code isn't valid" immediately, instead of the
  # coupon silently not discounting anything (or Checkout Session creation
  # crashing outright) much later at actual payment time.
  def stripe_promotion_code_active?(coupon)
    return false if coupon.stripe_promotion_code_id.blank?

    Stripe::PromotionCode.retrieve(coupon.stripe_promotion_code_id).active
  rescue Stripe::StripeError => e
    Rails.logger.error("Coupon validation: Stripe lookup failed for #{coupon.code} (#{coupon.stripe_promotion_code_id}): #{e.message}")
    Sentry.capture_exception(e)
    false
  end
end
