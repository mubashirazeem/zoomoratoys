require "rails_helper"

RSpec.describe Coupon, type: :model do
  it "has a valid factory" do
    expect(build(:coupon)).to be_valid
  end

  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_numericality_of(:discount_value).only_integer.is_greater_than(0) }
  it { is_expected.to define_enum_for(:discount_type).with_values(percentage: "percentage", fixed_amount: "fixed_amount").backed_by_column_of_type(:string) }

  it "rejects a duplicate code, case-insensitively" do
    create(:coupon, code: "SUMMER10")
    duplicate = build(:coupon, code: "summer10")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:code]).to be_present
  end

  it "uppercases the code before saving" do
    coupon = create(:coupon, code: "lowercase20")

    expect(coupon.code).to eq("LOWERCASE20")
  end

  it "rejects a code with a space, with a clear message — Stripe's own PromotionCode format doesn't allow it" do
    coupon = build(:coupon, code: "Test cop")

    expect(coupon).not_to be_valid
    expect(coupon.errors[:code].join).to include("letters, numbers, hyphens, and underscores")
  end

  it "rejects a code with punctuation Stripe doesn't allow, e.g. a percent sign" do
    coupon = build(:coupon, code: "SAVE20%")

    expect(coupon).not_to be_valid
  end

  it "allows hyphens and underscores, which Stripe's PromotionCode format does permit" do
    coupon = build(:coupon, code: "SUMMER-20_SALE")

    expect(coupon).to be_valid
  end

  it "rejects a percentage discount over 100" do
    coupon = build(:coupon, discount_type: "percentage", discount_value: 150)

    expect(coupon).not_to be_valid
  end

  it "allows a fixed_amount discount over 100" do
    coupon = build(:coupon, :fixed_amount, discount_value: 500)

    expect(coupon).to be_valid
  end

  describe "#expired?" do
    it "is true once expires_at is in the past" do
      expect(build(:coupon, :expired)).to be_expired
    end

    it "is false with no expiry set" do
      expect(build(:coupon, expires_at: nil)).not_to be_expired
    end
  end

  describe "#usage_limit_reached?" do
    it "is true once times_used reaches usage_limit" do
      expect(build(:coupon, :usage_limit_reached)).to be_usage_limit_reached
    end

    it "is false with no usage limit set" do
      expect(build(:coupon, usage_limit: nil)).not_to be_usage_limit_reached
    end
  end

  describe "#redeemable?" do
    it "is true for an active, unexpired coupon under its usage limit" do
      expect(build(:coupon)).to be_redeemable
    end

    it "is false when inactive" do
      expect(build(:coupon, active: false)).not_to be_redeemable
    end

    it "is false when expired" do
      expect(build(:coupon, :expired)).not_to be_redeemable
    end

    it "is false once the usage limit is reached" do
      expect(build(:coupon, :usage_limit_reached)).not_to be_redeemable
    end
  end
end
