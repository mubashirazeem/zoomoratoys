require "rails_helper"

RSpec.describe Product, type: :model do
  it "has a valid factory" do
    expect(build(:product)).to be_valid
  end

  it { is_expected.to belong_to(:category) }
  it { is_expected.to have_many(:reviews).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }
  it { is_expected.to validate_presence_of(:sku) }
  it { is_expected.to validate_numericality_of(:price_cents).only_integer.is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_inclusion_of(:placeholder_key).in_array(Category::PLACEHOLDER_KEYS) }
  it { is_expected.to define_enum_for(:stock_status).with_values(in_stock: "in_stock", sold_out: "sold_out", preorder: "preorder").backed_by_column_of_type(:string) }

  it "rejects a duplicate slug" do
    create(:product, slug: "kids-electric-jeep")
    duplicate = build(:product, slug: "kids-electric-jeep")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:slug]).to be_present
  end

  it "rejects a duplicate sku" do
    create(:product, sku: "ZMR-00001")
    duplicate = build(:product, sku: "ZMR-00001")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:sku]).to be_present
  end

  it "generates a slug from the name when none is given" do
    product = build(:product, name: "Kids Electric Jeep", slug: nil)

    product.valid?

    expect(product.slug).to eq("kids-electric-jeep")
  end

  it "defaults to in_stock" do
    expect(Product.new.stock_status).to eq("in_stock")
  end

  describe ".featured" do
    it "returns only featured products" do
      featured_product = create(:product, :featured)
      create(:product, featured: false)

      expect(Product.featured).to contain_exactly(featured_product)
    end
  end

  describe ".best_sellers" do
    it "returns only best-seller products" do
      best_seller = create(:product, :best_seller)
      create(:product, best_seller: false)

      expect(Product.best_sellers).to contain_exactly(best_seller)
    end
  end

  describe ".newest_first" do
    it "orders by creation time, most recent first" do
      older = create(:product, created_at: 2.days.ago)
      newer = create(:product, created_at: 1.hour.ago)

      expect(Product.newest_first).to eq([ newer, older ])
    end
  end

  describe "#to_param" do
    it "returns the slug" do
      product = build(:product, slug: "kids-electric-jeep")

      expect(product.to_param).to eq("kids-electric-jeep")
    end
  end

  describe "#average_rating" do
    it "returns nil when there are no reviews" do
      expect(create(:product).average_rating).to be_nil
    end

    it "returns the mean rating rounded to one decimal place" do
      product = create(:product)
      create(:review, product: product, rating: 5)
      create(:review, product: product, rating: 4)

      expect(product.average_rating).to eq(4.5)
    end
  end
end
