# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::BrandStoryComponent, type: :component do
  it "renders a slide for every category placeholder photo" do
    render_inline(described_class.new)

    slides = page.all("[data-promo-banner-slideshow-target='slide']", visible: :all)
    expect(slides.size).to eq(Category::PLACEHOLDER_KEYS.size)
  end

  it "marks only the first photo active" do
    render_inline(described_class.new)

    expect(page).to have_css("h2", text: "Driven by adventure. Built for innovation")
    expect(page).to have_text("Adventure")
    expect(page).to have_text("Categories")
    slides = page.all("[data-promo-banner-slideshow-target='slide']", visible: :all)
    expect(slides.first[:class]).to include("is-active")
    expect(slides.drop(1)).to all(satisfy { |s| !s[:class].include?("is-active") })
  end

  it "marks the rotating photo strip as decorative — the badge already states the count as real text" do
    render_inline(described_class.new)

    expect(page).to have_css("[data-controller='promo-banner-slideshow'][aria-hidden='true']")
  end
end
