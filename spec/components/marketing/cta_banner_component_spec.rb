# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::CtaBannerComponent, type: :component do
  it "renders the title, description, and CTA link" do
    render_inline(
      described_class.new(
        title: "Ready for your next adventure?",
        description: "Browse the full Zoomora Toys catalog.",
        cta_label: "Shop All",
        cta_url: "/shop"
      )
    )

    expect(page).to have_css("h2", text: "Ready for your next adventure?")
    expect(page).to have_text("Browse the full Zoomora Toys catalog.")
    expect(page).to have_link("Shop All", href: "/shop")
  end

  it "omits the description paragraph when none is given" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop"))

    expect(page).to have_css("h2", text: "Shop Now")
  end

  it "raises for an unknown tone" do
    expect { described_class.new(title: "x", cta_label: "y", cta_url: "/", tone: :neon) }.to raise_error(ArgumentError)
  end
end
