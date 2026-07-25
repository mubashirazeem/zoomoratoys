# frozen_string_literal: true

require "rails_helper"

RSpec.describe Catalog::ProductCardComponent, type: :component do
  it "renders the product name and price, linked to the product page" do
    product = build_stubbed(:product, name: "Trailhawk Off-Road Scooter", price_cents: 549_900, slug: "trailhawk-off-road-scooter")

    render_inline(described_class.new(product: product))

    expect(page).to have_link("Trailhawk Off-Road Scooter", href: "/shop/trailhawk-off-road-scooter")
    expect(page).to have_text("AED 5,499")
  end

  it "shows a Sold Out badge for sold-out products" do
    product = build_stubbed(:product, :sold_out)

    render_inline(described_class.new(product: product))

    expect(page).to have_text("Sold Out")
  end

  it "does not show a Sold Out badge for in-stock products" do
    product = build_stubbed(:product, stock_status: "in_stock")

    render_inline(described_class.new(product: product))

    expect(page).not_to have_text("Sold Out")
  end

  it "shows a Sold Out badge for a variant product only when every variant is actually empty" do
    product = create(:product, stock_status: "in_stock")
    create(:product_variant, product: product, stock_quantity: 0)
    create(:product_variant, product: product, stock_quantity: 3)

    render_inline(described_class.new(product: product))

    expect(page).not_to have_text("Sold Out")
  end

  it "shows a Sold Out badge for a variant product once every variant is genuinely empty, regardless of the parent's own status" do
    product = create(:product, stock_status: "in_stock")
    create(:product_variant, product: product, stock_quantity: 0)
    create(:product_variant, product: product, stock_quantity: 0)

    render_inline(described_class.new(product: product))

    expect(page).to have_text("Sold Out")
  end

  it "shows a real sale badge and struck-through price for a genuine compare-at price" do
    product = build_stubbed(:product, price_cents: 10_000, compare_at_price_cents: 12_700)

    render_inline(described_class.new(product: product))

    expect(page).to have_text("-21%")
    expect(page).to have_text("AED 127")
  end

  it "shows no sale badge without a compare-at price" do
    product = build_stubbed(:product, price_cents: 10_000, compare_at_price_cents: nil)

    render_inline(described_class.new(product: product))

    expect(page).not_to have_text("%")
  end

  it "gives the image link its own accessible name" do
    product = build_stubbed(:product, name: "Trailhawk Off-Road Scooter", slug: "trailhawk-off-road-scooter")

    render_inline(described_class.new(product: product))

    image_link = page.all("a").first
    expect(image_link["aria-label"]).to eq("Trailhawk Off-Road Scooter")
  end

  it "gives the product photo real alt text, not an empty string" do
    product = build_stubbed(:product, name: "Trailhawk Off-Road Scooter")

    render_inline(described_class.new(product: product))

    expect(page).to have_css("img[alt='Trailhawk Off-Road Scooter']")
  end
end
