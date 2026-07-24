# frozen_string_literal: true

class Coupon < ApplicationRecord
  # discount_value's unit depends on discount_type — a whole number 1-100
  # when percentage (e.g. 20 => 20% off), or a whole AED amount (not cents)
  # when fixed_amount (e.g. 50 => AED 50 off). Deliberately not cents here,
  # unlike Product#price_cents — this is a human-entered discount amount,
  # converted to cents only at display/application time.
  enum :discount_type, { percentage: "percentage", fixed_amount: "fixed_amount" },
       default: "percentage", validate: true

  # Matches Stripe's own PromotionCode format constraint exactly — letters,
  # digits, hyphens, and underscores only, no spaces or other punctuation.
  # Catches an invalid code at creation time with a plain-language message,
  # instead of letting it save locally and only fail later, confusingly,
  # at the Stripe sync step (Payments::CouponSync).
  CODE_FORMAT = /\A[a-zA-Z0-9\-_]+\z/

  validates :code, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: CODE_FORMAT, message: "can only contain letters, numbers, hyphens, and underscores (no spaces)" }
  validates :discount_value, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :times_used, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation { self.code = code.strip.upcase if code.present? }

  scope :active, -> { where(active: true) }

  def expired?
    expires_at.present? && expires_at.past?
  end

  def usage_limit_reached?
    usage_limit.present? && times_used >= usage_limit
  end

  def redeemable?
    active? && !expired? && !usage_limit_reached?
  end
end
