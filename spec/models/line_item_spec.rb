require "rails_helper"

RSpec.describe LineItem, type: :model do
  it "has a valid factory" do
    expect(build(:line_item)).to be_valid
  end

  it { is_expected.to belong_to(:order) }
  it { is_expected.to belong_to(:product) }
  it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than(0) }
  it { is_expected.to validate_numericality_of(:price_cents).only_integer.is_greater_than_or_equal_to(0) }
end
