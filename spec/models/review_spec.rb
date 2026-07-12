require "rails_helper"

RSpec.describe Review, type: :model do
  it "has a valid factory" do
    expect(build(:review)).to be_valid
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:product) }
  it { is_expected.to validate_presence_of(:comment) }
  it { is_expected.to validate_inclusion_of(:rating).in_range(1..5) }

  it "rejects a second review from the same user for the same product" do
    product = create(:product)
    user = create(:user)
    create(:review, user: user, product: product)
    duplicate = build(:review, user: user, product: product)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end

  it "allows the same user to review two different products" do
    user = create(:user)
    create(:review, user: user, product: create(:product))
    other = build(:review, user: user, product: create(:product))

    expect(other).to be_valid
  end

  describe ".newest_first" do
    it "orders by creation time, most recent first" do
      older = create(:review, created_at: 2.days.ago)
      newer = create(:review, created_at: 1.hour.ago)

      expect(Review.newest_first).to eq([ newer, older ])
    end
  end
end
