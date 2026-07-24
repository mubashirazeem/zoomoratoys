require "rails_helper"

RSpec.describe ProductVariant, type: :model do
  it "has a valid factory" do
    expect(build(:product_variant)).to be_valid
  end

  it { is_expected.to belong_to(:product) }
  it { is_expected.to have_many(:cart_items).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:sku) }

  describe "#destroy" do
    it "deletes cleanly and clears any cart references to it" do
      variant = create(:product_variant)
      cart_item = create(:cart_item, product: variant.product, product_variant: variant)

      expect(variant.destroy).to be_truthy
      expect(CartItem.exists?(cart_item.id)).to be false
    end
  end
end
