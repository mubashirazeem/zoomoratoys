# frozen_string_literal: true

require "rails_helper"

RSpec.describe Layout::MiniCartComponent, type: :component do
  it "renders each product with its name and a subtotal computed from real prices" do
    products = [
      build_stubbed(:product, name: "Trailblazer Junior 4x4", price_cents: 129_900),
      build_stubbed(:product, name: "Backyard Bounce 8ft", price_cents: 89_900)
    ]

    render_inline(described_class.new(products: products))

    expect(page).to have_link("Trailblazer Junior 4x4")
    expect(page).to have_link("Backyard Bounce 8ft")
    expect(page).to have_text("AED 2,198")
  end

  it "shows an empty-cart message with a link back to the shop when there are no items" do
    render_inline(described_class.new(products: []))

    expect(page).to have_text("Your cart is empty")
    expect(page).to have_link("Start Shopping", href: "/shop")
  end
end
