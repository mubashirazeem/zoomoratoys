# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::HeroComponent, type: :component do
  let(:slides) do
    [
      { image: "hero-bicycle.jpg", eyebrow: "Trusted. Tested. Loved.", headline: "Built For Every Adventure",
        cta_label: "Shop All", cta_url: "/shop" },
      { image: "category-atv.jpg", eyebrow: "Best Sellers", headline: "Power. Performance. Play.",
        cta_label: "Shop Best Sellers", cta_url: "/shop" }
    ]
  end

  it "renders each slide's eyebrow, headline, and CTA as real text and a real link" do
    render_inline(described_class.new(slides: slides))

    expect(page).to have_text("Trusted. Tested. Loved.")
    expect(page).to have_css("h2", text: "Built For Every Adventure")
    expect(page).to have_link("Shop All", href: "/shop")

    expect(page).to have_text("Best Sellers")
    expect(page).to have_css("h2", text: "Power. Performance. Play.")
    expect(page).to have_link("Shop Best Sellers", href: "/shop")
  end

  it "renders each slide's background photo as a decorative image (no text baked into the image)" do
    render_inline(described_class.new(slides: slides))

    images = page.all("[data-slideshow-target='face'] img")
    expect(images.size).to eq(2)
    expect(images.map { |img| img["alt"] }).to all(eq(""))
    expect(images.first["src"]).to include("hero-bicycle")
    expect(images.last["src"]).to include("category-atv")
  end

  it "marks only the first slide visible and the rest hidden from assistive tech" do
    render_inline(described_class.new(slides: slides))

    faces = page.all("[data-slideshow-target='face']")
    expect(faces.map { |f| f["aria-hidden"] }).to eq([ "false", "true" ])
  end

  it "renders labeled previous/next controls and one scrubber segment per slide" do
    render_inline(described_class.new(slides: slides))

    expect(page).to have_css("button[aria-label='Previous slide']")
    expect(page).to have_css("button[aria-label='Next slide']")
    expect(page).to have_css("[data-slideshow-target='segment']", count: 2)
  end
end
