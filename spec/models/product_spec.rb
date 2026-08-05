require "rails_helper"

RSpec.describe Product, type: :model do
  it "has a valid factory" do
    expect(build(:product)).to be_valid
  end

  it { is_expected.to belong_to(:category) }
  it { is_expected.to have_many(:reviews).dependent(:destroy) }
  it { is_expected.to have_many(:cart_items).dependent(:destroy) }
  it { is_expected.to have_many(:wishlist_items).dependent(:destroy) }
  it { is_expected.to have_many(:line_items).dependent(:restrict_with_error) }
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

  describe ".search" do
    it "matches on name, description, or sku, case-insensitively" do
      by_name = create(:product, name: "Trailhawk Scooter")
      by_description = create(:product, description: "A rugged SCOOTER for the whole family")
      by_sku = create(:product, sku: "ZMR-SCOOTER1")
      non_match = create(:product, name: "Golf Cart", description: "Four seats", sku: "ZMR-00099")

      results = Product.search("scooter")

      expect(results).to include(by_name, by_description, by_sku)
      expect(results).not_to include(non_match)
    end

    it "escapes the query's own SQL LIKE wildcard characters" do
      create(:product, name: "50% Off Special")
      unrelated = create(:product, name: "Anything at all")

      results = Product.search("50%")

      expect(results).not_to include(unrelated)
    end
  end

  describe ".price_between" do
    it "filters by an inclusive range" do
      cheap = create(:product, price_cents: 5_000)
      mid = create(:product, price_cents: 15_000)
      expensive = create(:product, price_cents: 500_000)

      expect(Product.price_between(10_000, 20_000)).to contain_exactly(mid)
      expect(Product.price_between(nil, 10_000)).to contain_exactly(cheap)
      expect(Product.price_between(20_000, nil)).to contain_exactly(expensive)
    end
  end

  describe ".with_variant_color" do
    it "returns only products with a matching real variant color" do
      red_product = create(:product)
      create(:product_variant, product: red_product, options: { "Color" => "Racing Red" })
      black_product = create(:product)
      create(:product_variant, product: black_product, options: { "Color" => "Midnight Black" })
      no_variant_product = create(:product)

      results = Product.with_variant_color([ "Racing Red" ])

      expect(results).to contain_exactly(red_product)
      expect(results).not_to include(black_product, no_variant_product)
    end
  end

  describe ".sorted_by" do
    it "sorts by price ascending/descending, or newest, falling back to .ordered" do
      cheap = create(:product, price_cents: 100, name: "A")
      expensive = create(:product, price_cents: 999_00, name: "B")

      expect(Product.sorted_by("price_asc").to_a).to eq([ cheap, expensive ])
      expect(Product.sorted_by("price_desc").to_a).to eq([ expensive, cheap ])
      expect(Product.sorted_by(nil).to_a).to eq(Product.ordered.to_a)
    end
  end

  describe ".available_variant_colors" do
    it "returns real, distinct Color values from actual variants" do
      product = create(:product)
      create(:product_variant, product: product, options: { "Color" => "Racing Red" })
      create(:product_variant, product: product, options: { "Color" => "Racing Red" })
      create(:product_variant, product: product, options: { "Color" => "Midnight Black" })
      create(:product_variant, product: create(:product), options: { "Size" => "Large" })

      expect(Product.available_variant_colors).to contain_exactly("Racing Red", "Midnight Black")
    end

    it "scopes to a relation when called on one, instead of listing every color in the catalog" do
      scooters = create(:category)
      pools = create(:category)
      scooter_product = create(:product, category: scooters)
      pool_product = create(:product, category: pools)
      create(:product_variant, product: scooter_product, options: { "Color" => "Racing Red" })
      create(:product_variant, product: pool_product, options: { "Color" => "Ocean Blue" })

      expect(Product.where(category: scooters).available_variant_colors).to contain_exactly("Racing Red")
    end
  end

  describe "#to_param" do
    it "returns the slug" do
      product = build(:product, slug: "kids-electric-jeep")

      expect(product.to_param).to eq("kids-electric-jeep")
    end
  end

  describe "compare-at price / on_sale?" do
    it "is not on sale with no compare-at price" do
      product = build(:product, price_cents: 10_000, compare_at_price_cents: nil)

      expect(product.on_sale?).to be false
      expect(product.discount_percent).to be_nil
    end

    it "is on sale when the compare-at price is genuinely higher" do
      product = build(:product, price_cents: 10_000, compare_at_price_cents: 12_700)

      expect(product.on_sale?).to be true
      expect(product.discount_percent).to eq(21)
    end

    it "rejects a compare-at price that isn't actually higher than the price" do
      product = build(:product, price_cents: 10_000, compare_at_price_cents: 10_000)

      expect(product).not_to be_valid
      expect(product.errors[:compare_at_price_cents]).to be_present
    end

    it "clears the compare-at price when the virtual setter receives blank" do
      product = create(:product, price_cents: 10_000, compare_at_price_cents: 12_700)

      product.compare_at_price = ""

      expect(product.compare_at_price_cents).to be_nil
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

  describe "#display_photo" do
    it "returns the category placeholder path when no photo has been uploaded" do
      product = build_stubbed(:product, placeholder_key: "bicycle")

      expect(product.display_photo).to eq("category-bicycle.jpg")
    end

    it "returns a variant of the first uploaded photo once one exists" do
      product = create(:product)
      product.images.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample_product_image.jpg")),
        filename: "sample_product_image.jpg",
        content_type: "image/jpeg"
      )

      expect(product.display_photo(resize_to_limit: [ 100, 100 ])).to be_a(ActiveStorage::VariantWithRecord)
    end
  end

  describe "stock_status syncing with stock_quantity" do
    it "flips in_stock to sold_out when a normal save drops quantity to zero" do
      product = create(:product, stock_quantity: 5, stock_status: "in_stock")

      product.update!(stock_quantity: 0)

      expect(product.stock_status).to eq("sold_out")
    end

    it "flips sold_out back to in_stock when a normal save restores quantity" do
      product = create(:product, stock_quantity: 0, stock_status: "sold_out")

      product.update!(stock_quantity: 4)

      expect(product.stock_status).to eq("in_stock")
    end

    it "never touches a preorder product's status, regardless of quantity" do
      product = create(:product, stock_quantity: 0, stock_status: "preorder")

      product.update!(stock_quantity: 10)

      expect(product.reload.stock_status).to eq("preorder")
    end

    it "leaves stock_status alone when quantity doesn't change" do
      product = create(:product, stock_quantity: 5, stock_status: "in_stock")

      product.update!(name: "Renamed")

      expect(product.stock_status).to eq("in_stock")
    end

    it "respects an explicit stock_status set in the same save, even when quantity also changes — e.g. deliberately marking something a preorder while also zeroing out the count" do
      product = create(:product, stock_quantity: 5, stock_status: "in_stock")

      product.update!(stock_quantity: 0, stock_status: "preorder")

      expect(product.reload.stock_status).to eq("preorder")
    end

    describe "#sync_stock_status! — the explicit path used after decrement!/increment!, which bypass callbacks" do
      it "corrects a stale sold_out status once quantity is restored" do
        product = create(:product, stock_quantity: 0, stock_status: "sold_out")
        product.increment!(:stock_quantity, 3)

        product.sync_stock_status!

        expect(product.reload.stock_status).to eq("in_stock")
      end

      it "corrects a stale in_stock status once quantity hits zero" do
        product = create(:product, stock_quantity: 3, stock_status: "in_stock")
        product.decrement!(:stock_quantity, 3)

        product.sync_stock_status!

        expect(product.reload.stock_status).to eq("sold_out")
      end

      it "never touches a preorder product" do
        product = create(:product, stock_quantity: 0, stock_status: "preorder")

        product.sync_stock_status!

        expect(product.reload.stock_status).to eq("preorder")
      end
    end
  end

  describe "#out_of_stock?" do
    it "is true for a plain product with sold_out status" do
      product = build(:product, stock_status: "sold_out")

      expect(product.out_of_stock?).to be true
    end

    it "is false for a plain product with in_stock status" do
      product = build(:product, stock_status: "in_stock")

      expect(product.out_of_stock?).to be false
    end

    it "is false for any product with variants that still have stock, regardless of the parent's own status" do
      product = create(:product, stock_status: "sold_out")
      create(:product_variant, product: product, stock_quantity: 2)

      expect(product.out_of_stock?).to be false
    end

    it "is true only when every variant is out of stock, regardless of the parent's own status" do
      product = create(:product, stock_status: "in_stock")
      create(:product_variant, product: product, stock_quantity: 0)
      create(:product_variant, product: product, stock_quantity: 0)

      expect(product.out_of_stock?).to be true
    end
  end

  describe "#destroy" do
    it "refuses to delete a product that's ever been ordered, with a real error instead of a crash" do
      product = create(:product)
      create(:line_item, product: product)

      expect(product.destroy).to be false
      expect(product.errors[:base]).to be_present
      expect(Product.exists?(product.id)).to be true
    end

    it "deletes cleanly and clears any cart/wishlist references when there's no order history" do
      product = create(:product)
      cart_item = create(:cart_item, product: product)
      wishlist_item = create(:wishlist_item, product: product)

      expect(product.destroy).to be_truthy
      expect(CartItem.exists?(cart_item.id)).to be false
      expect(WishlistItem.exists?(wishlist_item.id)).to be false
    end
  end
end
