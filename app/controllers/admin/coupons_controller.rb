# frozen_string_literal: true

class Admin::CouponsController < Admin::BaseController
  before_action :set_coupon, only: [ :edit, :update, :destroy ]

  def index
    @coupons = Coupon.order(created_at: :desc)
  end

  def new
    @coupon = Coupon.new
  end

  def create
    @coupon = Coupon.new(coupon_params)

    if @coupon.save
      sync_notice = sync_to_stripe { Payments::CouponSync.create(@coupon) }
      redirect_to admin_coupons_path, notice: "Coupon created.", alert: sync_notice
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @coupon.update(coupon_params)
      sync_notice = sync_to_stripe { Payments::CouponSync.update(@coupon) }
      redirect_to admin_coupons_path, notice: "Coupon updated.", alert: sync_notice
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @coupon.destroy
    sync_to_stripe { Payments::CouponSync.deactivate(@coupon) }
    redirect_to admin_coupons_path, notice: "Coupon deleted."
  end

  private

  def set_coupon
    @coupon = Coupon.find(params[:id])
  end

  def coupon_params
    params.require(:coupon).permit(:code, :discount_type, :discount_value, :active, :expires_at, :usage_limit)
  end

  # Deliberately not an ActiveRecord callback — a network call to a third
  # party inside an after_commit hook can silently swallow a real failure
  # or block an unrelated DB write. Doing it here means the coupon always
  # saves in our own database regardless of Stripe's availability, and a
  # sync failure surfaces as a clear, honest flash message instead of
  # silently lying about sync state.
  def sync_to_stripe
    yield
    nil
  rescue Stripe::StripeError => e
    "Stripe sync failed — it won't be redeemable at checkout yet: #{e.message}"
  end
end
