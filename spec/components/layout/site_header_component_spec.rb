# frozen_string_literal: true

require "rails_helper"

RSpec.describe Layout::SiteHeaderComponent, type: :component do
  it "renders the logo image, linking home, with an accessible name" do
    render_inline(described_class.new)

    expect(page).to have_css("a[href='/'] img[alt='Zoomora Toys — Adventure Starts Here']")
  end

  it "renders Home, About, and Contact around the category links" do
    render_inline(described_class.new)

    expect(page).to have_link("Home", href: "/")
    expect(page).to have_link("About", href: "/about")
    expect(page).to have_link("Contact", href: "/contact")
  end

  it "renders a short nav label and shop link for each category" do
    scooters = build_stubbed(:category, slug: "electric-scooters", placeholder_key: "scooter")
    golf = build_stubbed(:category, slug: "golf-carts", placeholder_key: "golf_cart")

    render_inline(described_class.new(categories: [ scooters, golf ]))

    expect(page).to have_link("Scooters", href: "/shop?category=electric-scooters")
    expect(page).to have_link("Golf Carts", href: "/shop?category=golf-carts")
  end

  it "renders a store search form pointing at the shop page" do
    render_inline(described_class.new)

    expect(page).to have_css("form[action='/shop'][method='get'] input[name='q']")
  end

  it "renders a labeled mobile menu trigger" do
    render_inline(described_class.new)

    expect(page).to have_css("button[aria-label='Open menu']")
  end
end
