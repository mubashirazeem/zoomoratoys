# frozen_string_literal: true

require "rails_helper"

RSpec.describe Catalog::ProductVariantsComponent, type: :component do
  it "renders nothing when the product has no real variants" do
    product = create(:product)

    render_inline(described_class.new(product: product))

    expect(page).to have_no_css("button")
  end

  it "renders a real option group per option type the admin actually defined" do
    product = create(:product)
    create(:product_variant, product: product, options: { "Color" => "Racing Red", "Size" => "Standard" })
    create(:product_variant, product: product, options: { "Color" => "Midnight Black", "Size" => "Standard" })

    render_inline(described_class.new(product: product))

    expect(page).to have_text("Color:")
    expect(page).to have_text("Size:")
    expect(page).to have_button("Racing Red")
    expect(page).to have_button("Midnight Black")
  end

  it "shows the first variant's real SKU and price as the default selection" do
    product = create(:product, price_cents: 10_000)
    create(:product_variant, product: product, sku: "ZMR-VAR-00001", price_cents: 12_000, options: { "Color" => "Racing Red" })

    render_inline(described_class.new(product: product))

    expect(page).to have_text("ZMR-VAR-00001")
    expect(page).to have_text("AED 120")
  end

  it "shows an out-of-stock notice for a variant with zero stock" do
    product = create(:product)
    create(:product_variant, product: product, stock_quantity: 0, options: { "Color" => "Racing Red" })

    render_inline(described_class.new(product: product))

    expect(page).to have_text("Out of stock")
  end
end
