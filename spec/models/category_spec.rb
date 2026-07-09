require "rails_helper"

RSpec.describe Category, type: :model do
  it "has a valid factory" do
    expect(build(:category)).to be_valid
  end

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }
  it { is_expected.to validate_inclusion_of(:placeholder_key).in_array(Category::PLACEHOLDER_KEYS) }
  it { is_expected.to have_many(:products) }

  it "rejects a duplicate slug" do
    create(:category, slug: "electric-scooters")
    duplicate = build(:category, slug: "electric-scooters")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:slug]).to be_present
  end

  it "generates a slug from the name when none is given" do
    category = build(:category, name: "Electric Scooters", slug: nil)

    category.valid?

    expect(category.slug).to eq("electric-scooters")
  end

  it "does not overwrite an explicitly assigned slug" do
    category = build(:category, name: "Electric Scooters", slug: "custom-slug")

    category.valid?

    expect(category.slug).to eq("custom-slug")
  end

  describe ".ordered" do
    it "orders by position then name" do
      second = create(:category, name: "Z Category", position: 1)
      first = create(:category, name: "A Category", position: 0)

      expect(Category.ordered).to eq([ first, second ])
    end
  end

  describe "#to_param" do
    it "returns the slug" do
      category = build(:category, slug: "golf-carts")

      expect(category.to_param).to eq("golf-carts")
    end
  end
end
