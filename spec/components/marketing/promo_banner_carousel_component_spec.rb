# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::PromoBannerCarouselComponent, type: :component do
  it "renders every banner's title, description, and CTA link when it has one" do
    banners = [
      create(:promotional_banner, title: "Buy Now, Pay Later", description: "Split it up.", cta_label: "Shop All", cta_url: "/shop"),
      create(:promotional_banner, title: "Free Delivery", description: "Anywhere in the UAE.", cta_label: nil, cta_url: nil)
    ]

    render_inline(described_class.new(banners: banners))

    expect(page).to have_css("h2", text: "Buy Now, Pay Later")
    expect(page).to have_text("Split it up.")
    expect(page).to have_link("Shop All", href: "/shop")
    expect(page).to have_css("h2", text: "Free Delivery")
  end

  it "renders no button for a banner with no CTA" do
    banner = create(:promotional_banner, cta_label: nil, cta_url: nil)

    render_inline(described_class.new(banners: [ banner ]))

    expect(page).to have_no_css("a.inline-flex")
  end

  it "marks only the first slide active/visible-to-assistive-tech, the rest hidden until their turn" do
    banners = create_list(:promotional_banner, 2)

    render_inline(described_class.new(banners: banners))

    slides = page.all("[data-promo-banner-slideshow-target='slide']", visible: :all)
    expect(slides[0][:class]).to include("is-active")
    expect(slides[0]["aria-hidden"]).to eq("false")
    expect(slides[1][:class]).not_to include("is-active")
    expect(slides[1]["aria-hidden"]).to eq("true")
  end

  it "renders one navigation dot per banner, marking the first current" do
    banners = create_list(:promotional_banner, 2)

    render_inline(described_class.new(banners: banners))

    dots = page.all("[data-promo-banner-slideshow-target='dot']", visible: :all)
    expect(dots.size).to eq(2)
    expect(dots[0]["aria-current"]).to eq("true")
    expect(dots[1]["aria-current"]).to eq("false")
  end

  it "renders no dots or arrows for a single banner — nothing to navigate between" do
    render_inline(described_class.new(banners: [ create(:promotional_banner) ]))

    expect(page).to have_no_css("[data-promo-banner-slideshow-target='dot']", visible: :all)
    expect(page).to have_no_css("button[aria-label='Previous promotion']")
  end

  it "falls back to a plain dark background when no photo has been uploaded" do
    banner = create(:promotional_banner)
    expect(banner.image).not_to be_attached

    render_inline(described_class.new(banners: [ banner ]))

    expect(page).to have_css(".bg-ink-950")
  end

  it "renders full-bleed, matching the hero's own width and height, not a smaller boxed card — client feedback (2026-08-02): 'increase this banner size... like the first one on top'" do
    render_inline(described_class.new(banners: [ create(:promotional_banner) ]))

    slide = page.find("[data-promo-banner-slideshow-target='slide']", visible: :all)
    expect(slide[:class]).to include("w-full")
    expect(slide[:class]).not_to include("max-w-7xl")
    expect(slide[:class]).not_to include("rounded-")
    expect(slide[:class]).to include("h-[440px]")
  end
end
