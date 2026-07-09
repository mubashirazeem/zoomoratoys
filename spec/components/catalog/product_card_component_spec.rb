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

  it "gives the image link an accessible name since the photo's alt text is empty/decorative" do
    product = build_stubbed(:product, name: "Trailhawk Off-Road Scooter", slug: "trailhawk-off-road-scooter")

    render_inline(described_class.new(product: product))

    image_link = page.all("a").first
    expect(image_link["aria-label"]).to eq("Trailhawk Off-Road Scooter")
  end
end
