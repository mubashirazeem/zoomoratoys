require "rails_helper"

RSpec.describe PromotionalBanner, type: :model do
  it "is valid with just a title" do
    banner = build(:promotional_banner, title: "Summer Sale", cta_label: nil, cta_url: nil)

    expect(banner).to be_valid
  end

  it "requires a title" do
    banner = build(:promotional_banner, title: nil)

    expect(banner).not_to be_valid
  end

  it "rejects a button label with no link" do
    banner = build(:promotional_banner, cta_label: "Shop All", cta_url: nil)

    expect(banner).not_to be_valid
    expect(banner.errors[:base]).to be_present
  end

  it "rejects a button link with no label" do
    banner = build(:promotional_banner, cta_label: nil, cta_url: "/shop")

    expect(banner).not_to be_valid
  end

  it "is valid with both button label and link present" do
    banner = build(:promotional_banner, cta_label: "Shop All", cta_url: "/shop")

    expect(banner).to be_valid
  end

  describe "#cta?" do
    it "is true only when both label and url are present" do
      expect(build(:promotional_banner, cta_label: "Shop All", cta_url: "/shop").cta?).to be true
      expect(build(:promotional_banner, cta_label: nil, cta_url: nil).cta?).to be false
    end
  end

  describe ".active" do
    it "only returns active banners" do
      active = create(:promotional_banner, active: true)
      create(:promotional_banner, active: false)

      expect(PromotionalBanner.active).to eq([ active ])
    end
  end

  describe ".ordered" do
    it "orders by position" do
      third = create(:promotional_banner, position: 2)
      first = create(:promotional_banner, position: 0)
      second = create(:promotional_banner, position: 1)

      expect(PromotionalBanner.ordered).to eq([ first, second, third ])
    end
  end
end
