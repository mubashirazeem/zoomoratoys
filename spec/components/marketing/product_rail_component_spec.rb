# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::ProductRailComponent, type: :component do
  it "renders a card for every product" do
    products = build_stubbed_list(:product, 3)

    render_inline(described_class.new(title: "Best Sellers", products: products))

    products.each { |product| expect(page).to have_text(product.name) }
  end

  it "renders the section title" do
    render_inline(described_class.new(title: "New Arrivals", products: []))

    expect(page).to have_css("h2", text: "New Arrivals")
  end

  it "renders prev/next carousel controls" do
    render_inline(described_class.new(title: "Best Sellers", products: []))

    expect(page).to have_css("button[aria-label='Previous']")
    expect(page).to have_css("button[aria-label='Next']")
  end

  it "renders a view-all link when given" do
    render_inline(described_class.new(title: "Best Sellers", products: [], view_all_url: "/shop"))

    expect(page).to have_link("View All", href: "/shop")
  end
end
