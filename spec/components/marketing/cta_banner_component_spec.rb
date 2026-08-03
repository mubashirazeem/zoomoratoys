# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::CtaBannerComponent, type: :component do
  it "renders the title, description, and CTA link" do
    render_inline(
      described_class.new(
        title: "Ready for your next adventure?",
        description: "Browse the full Zoomora catalog.",
        cta_label: "Shop All",
        cta_url: "/shop"
      )
    )

    expect(page).to have_css("h2", text: "Ready for your next adventure?")
    expect(page).to have_text("Browse the full Zoomora catalog.")
    expect(page).to have_link("Shop All", href: "/shop")
  end

  it "omits the description paragraph when none is given" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop"))

    expect(page).to have_css("h2", text: "Shop Now")
  end

  it "raises for an unknown tone" do
    expect { described_class.new(title: "x", cta_label: "y", cta_url: "/", tone: :neon) }.to raise_error(ArgumentError)
  end

  it "defaults to a boxed, rounded card — existing usages (FAQ, About) must not change" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop"))

    expect(page).to have_css("section.rounded-\\[24px\\]")
    expect(page).to have_no_css("section.w-full")
  end

  it "renders edge-to-edge with no rounded corners when full_bleed is true (client feedback, 2026-08-03: banner should be '100%' size, not a smaller boxed card)" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop", full_bleed: true))

    expect(page).to have_css("section.w-full")
    expect(page).to have_no_css("section.rounded-\\[24px\\]")
  end

  it "uppercases the heading and CTA button, matching the hero's headline/button treatment (client feedback, 2026-08-03: mixed upper/lower case looked odd)" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop"))

    expect(page).to have_css("h2.uppercase", text: "Shop Now")
    expect(page).to have_css("a.uppercase", text: "Go")
  end

  it "renders no photo slides or nav arrows when no photos are given — existing boxed/full_bleed usages without photos are unaffected" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop", full_bleed: true))

    expect(page).to have_no_css("[data-promo-banner-slideshow-target='slide']")
    expect(page).to have_no_css("[data-action='promo-banner-slideshow#next']")
  end

  it "renders a photo slideshow with forward/back arrows when photos are given (client feedback, 2026-08-03: 'pictures here and buttons to move')" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop", full_bleed: true, photos: %w[category-atv.jpg category-bicycle.jpg category-dirtbike.jpg]))

    slides = page.all("[data-promo-banner-slideshow-target='slide']", visible: :all)
    expect(slides.size).to eq(3)
    expect(slides.first[:class]).to include("is-active")
    expect(page).to have_css("[data-controller='promo-banner-slideshow']")
    expect(page).to have_css("[data-action='promo-banner-slideshow#prev']")
    expect(page).to have_css("[data-action='promo-banner-slideshow#next']")
  end

  it "pauses autoplay on hover and focus, matching the promo banner carousel's interaction contract" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop", full_bleed: true, photos: %w[category-atv.jpg category-bicycle.jpg category-dirtbike.jpg]))

    wrapper = page.find("[data-controller='promo-banner-slideshow']")
    expect(wrapper["data-action"]).to include("mouseenter->promo-banner-slideshow#stop")
    expect(wrapper["data-action"]).to include("mouseleave->promo-banner-slideshow#start")
    expect(wrapper["data-action"]).to include("focusin->promo-banner-slideshow#stop")
    expect(wrapper["data-action"]).to include("focusout->promo-banner-slideshow#start")
  end

  it "renders one pagination dot per photo, matching the client's reference screenshot which showed dots below the arrows" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop", full_bleed: true, photos: %w[category-atv.jpg category-bicycle.jpg category-dirtbike.jpg]))

    dots = page.all("[data-promo-banner-slideshow-target='dot']", visible: :all)
    expect(dots.size).to eq(3)
    expect(dots.first["aria-current"]).to eq("true")
    expect(dots.drop(1)).to all(satisfy { |d| d["aria-current"] == "false" })
  end

  it "omits nav arrows and dots for a single photo — nothing to move between" do
    render_inline(described_class.new(title: "Shop Now", cta_label: "Go", cta_url: "/shop", full_bleed: true, photos: %w[category-atv.jpg]))

    expect(page).to have_css("[data-promo-banner-slideshow-target='slide']", count: 1)
    expect(page).to have_no_css("[data-action='promo-banner-slideshow#next']")
    expect(page).to have_no_css("[data-promo-banner-slideshow-target='dot']")
  end
end
