require "rails_helper"

RSpec.describe Order, type: :model do
  it "has a valid factory" do
    expect(build(:order)).to be_valid
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:line_items).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:order_number) }
  it { is_expected.to validate_presence_of(:placed_at) }
  it { is_expected.to validate_numericality_of(:total_cents).only_integer.is_greater_than_or_equal_to(0) }
  it {
    is_expected.to define_enum_for(:status)
      .with_values(pending: "pending", processing: "processing", shipped: "shipped",
                    delivered: "delivered", cancelled: "cancelled")
      .backed_by_column_of_type(:string)
  }

  it "rejects a duplicate order_number" do
    create(:order, order_number: "ZT-000001")
    duplicate = build(:order, order_number: "ZT-000001")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:order_number]).to be_present
  end

  it "defaults to pending" do
    expect(Order.new.status).to eq("pending")
  end

  describe ".newest_first" do
    it "orders by placed_at, most recent first" do
      older = create(:order, placed_at: 2.days.ago)
      newer = create(:order, placed_at: 1.hour.ago)

      expect(Order.newest_first).to eq([ newer, older ])
    end
  end
end
