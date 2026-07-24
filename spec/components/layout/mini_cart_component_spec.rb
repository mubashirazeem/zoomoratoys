# frozen_string_literal: true

require "rails_helper"

RSpec.describe Layout::MiniCartComponent, type: :component do
  it "renders each real cart item with its name and a real subtotal" do
    cart = create(:cart)
    item_a = create(:cart_item, cart: cart, product: create(:product, name: "Trailblazer Junior 4x4", price_cents: 129_900))
    item_b = create(:cart_item, cart: cart, product: create(:product, name: "Backyard Bounce 8ft", price_cents: 89_900))

    render_inline(described_class.new(cart_items: [ item_a, item_b ], subtotal_cents: 219_800))

    expect(page).to have_link("Trailblazer Junior 4x4")
    expect(page).to have_link("Backyard Bounce 8ft")
    expect(page).to have_text("AED 2,198")
  end

  it "shows an empty-cart message with a link back to the shop when there are no items" do
    render_inline(described_class.new(cart_items: [], subtotal_cents: 0))

    expect(page).to have_text("Your cart is empty")
    expect(page).to have_link("Start Shopping", href: "/shop")
  end
end
