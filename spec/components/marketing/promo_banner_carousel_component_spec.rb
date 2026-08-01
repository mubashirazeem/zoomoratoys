# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::PromoBannerCarouselComponent, type: :component do
  let(:banners) do
    [
      { title: "Buy Now, Pay Later", description: "Split it up.", cta_label: "Shop All", cta_url: "/shop", tone: :dark },
      { title: "Free Delivery", description: "Anywhere in the UAE.", cta_label: "Start Shopping", cta_url: "/shop", tone: :light }
    ]
  end

  it "renders every banner's title, description, and a real working CTA link" do
    render_inline(described_class.new(banners: banners))

    expect(page).to have_css("h2", text: "Buy Now, Pay Later")
    expect(page).to have_text("Split it up.")
    expect(page).to have_link("Shop All", href: "/shop")
    expect(page).to have_css("h2", text: "Free Delivery")
    expect(page).to have_link("Start Shopping", href: "/shop")
  end

  it "marks only the first slide active/visible-to-assistive-tech, the rest hidden until their turn" do
    render_inline(described_class.new(banners: banners))

    slides = page.all("[data-promo-banner-slideshow-target='slide']", visible: :all)
    expect(slides[0][:class]).to include("is-active")
    expect(slides[0]["aria-hidden"]).to eq("false")
    expect(slides[1][:class]).not_to include("is-active")
    expect(slides[1]["aria-hidden"]).to eq("true")
  end

  it "renders one navigation dot per banner, marking the first current" do
    render_inline(described_class.new(banners: banners))

    dots = page.all("[data-promo-banner-slideshow-target='dot']", visible: :all)
    expect(dots.size).to eq(2)
    expect(dots[0]["aria-current"]).to eq("true")
    expect(dots[1]["aria-current"]).to eq("false")
  end

  it "renders no dots for a single banner — nothing to navigate between" do
    render_inline(described_class.new(banners: [ banners.first ]))

    expect(page).to have_no_css("[data-promo-banner-slideshow-target='dot']", visible: :all)
  end

  it "renders Previous/Next arrow buttons" do
    render_inline(described_class.new(banners: banners))

    expect(page).to have_css("button[aria-label='Previous promotion']")
    expect(page).to have_css("button[aria-label='Next promotion']")
  end

  it "renders no arrow buttons for a single banner" do
    render_inline(described_class.new(banners: [ banners.first ]))

    expect(page).to have_no_css("button[aria-label='Previous promotion']")
    expect(page).to have_no_css("button[aria-label='Next promotion']")
  end
end
