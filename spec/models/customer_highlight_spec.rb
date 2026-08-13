require "rails_helper"

RSpec.describe CustomerHighlight, type: :model do
  it "is valid with a name, quote, and rating — no photo required" do
    highlight = build(:customer_highlight, customer_name: "Ahmed R.", quote: "Great bike!", rating: 5)

    expect(highlight).to be_valid
  end

  it "requires a customer name" do
    highlight = build(:customer_highlight, customer_name: nil)

    expect(highlight).not_to be_valid
  end

  it "requires a quote" do
    highlight = build(:customer_highlight, quote: nil)

    expect(highlight).not_to be_valid
  end

  it "rejects a rating outside 1..5" do
    expect(build(:customer_highlight, rating: 0)).not_to be_valid
    expect(build(:customer_highlight, rating: 6)).not_to be_valid
  end

  describe ".active" do
    it "only returns active highlights" do
      active = create(:customer_highlight, active: true)
      create(:customer_highlight, active: false)

      expect(CustomerHighlight.active).to eq([ active ])
    end
  end

  describe ".ordered" do
    it "orders by position" do
      third = create(:customer_highlight, position: 2)
      first = create(:customer_highlight, position: 0)
      second = create(:customer_highlight, position: 1)

      expect(CustomerHighlight.ordered).to eq([ first, second, third ])
    end
  end
end
