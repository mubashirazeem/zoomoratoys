# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::HeroComponent, type: :component do
  it "renders the headline, subheadline, and CTA as real text and a real link" do
    render_inline(
      described_class.new(
        headline: "Built For Every Adventure",
        subheadline: "Ride-ons, scooters, golf carts, and more.",
        cta_label: "Shop All",
        cta_url: "/shop",
        image: "hero-bicycle.jpg"
      )
    )

    expect(page).to have_css("h1", text: "Built For Every Adventure")
    expect(page).to have_text("Ride-ons, scooters, golf carts, and more.")
    expect(page).to have_link("Shop All", href: "/shop")
  end

  it "renders the background photo as a decorative image" do
    render_inline(
      described_class.new(
        headline: "H", subheadline: "S", cta_label: "Go", cta_url: "/shop", image: "hero-bicycle.jpg"
      )
    )

    image = page.find("img")
    expect(image["alt"]).to eq("")
    expect(image["src"]).to include("hero-bicycle")
  end
end
