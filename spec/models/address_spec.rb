require "rails_helper"

RSpec.describe Address, type: :model do
  it "has a valid factory" do
    expect(build(:address)).to be_valid
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:full_name) }
  it { is_expected.to validate_presence_of(:phone) }
  it { is_expected.to validate_presence_of(:address_line1) }
  it { is_expected.to validate_presence_of(:city) }
  it { is_expected.to validate_inclusion_of(:emirate).in_array(Order::EMIRATES) }

  it "unsets other defaults when a new one is marked default" do
    user = create(:user)
    first = create(:address, user: user, default_address: true)

    second = create(:address, user: user, default_address: true)

    expect(first.reload.default_address).to be false
    expect(second.reload.default_address).to be true
  end

  describe "#summary" do
    it "joins the address parts, skipping blank line2" do
      address = build(:address, address_line1: "Villa 12", address_line2: nil, city: "Dubai", emirate: "Dubai")

      expect(address.summary).to eq("Villa 12, Dubai, Dubai")
    end
  end
end
