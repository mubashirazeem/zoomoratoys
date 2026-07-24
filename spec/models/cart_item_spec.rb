require "rails_helper"

RSpec.describe CartItem, type: :model do
  it { is_expected.to belong_to(:cart) }
  it { is_expected.to belong_to(:product) }
  it { is_expected.to belong_to(:product_variant).optional }
  it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than(0) }

  describe "#available_stock" do
    it "reads the product's own stock when there's no variant" do
      product = create(:product, stock_quantity: 7)
      item = build(:cart_item, product: product, product_variant: nil)

      expect(item.available_stock).to eq(7)
    end

    it "reads the variant's stock, not the parent product's, when a variant is chosen" do
      product = create(:product, stock_quantity: 50)
      variant = create(:product_variant, product: product, stock_quantity: 3)
      item = build(:cart_item, product: product, product_variant: variant)

      expect(item.available_stock).to eq(3)
    end
  end

  describe "#stock_shortfall?" do
    it "is true when the cart quantity exceeds what's actually available" do
      product = create(:product, stock_quantity: 2)
      item = build(:cart_item, product: product, product_variant: nil, quantity: 3)

      expect(item.stock_shortfall?).to be true
    end

    it "is false when there's enough stock for the cart quantity" do
      product = create(:product, stock_quantity: 5)
      item = build(:cart_item, product: product, product_variant: nil, quantity: 3)

      expect(item.stock_shortfall?).to be false
    end
  end
end
