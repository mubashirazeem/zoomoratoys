# frozen_string_literal: true

require "rails_helper"

RSpec.describe Layout::SiteFooterComponent, type: :component do
  it "renders the logo image" do
    render_inline(described_class.new)

    expect(page).to have_css("img[alt='Zoomora']")
  end

  it "renders the primary footer nav links" do
    render_inline(described_class.new)

    expect(page).to have_link("Shop All", href: "/shop")
    expect(page).to have_link("Categories", href: "/categories")
    expect(page).to have_link("About Us", href: "/about")
    expect(page).to have_link("Contact Us", href: "/contact")
  end

  it "renders a link for every given category" do
    categories = build_stubbed_list(:category, 2)

    render_inline(described_class.new(categories: categories))

    categories.each do |category|
      expect(page).to have_link(category.name, href: "/shop?category=#{category.slug}")
    end
  end

  it "renders contact details and the current year in the copyright line" do
    render_inline(described_class.new)

    expect(page).to have_link(href: "mailto:hello@zoomora.com")
    expect(page).to have_text("Dubai, United Arab Emirates")
    expect(page).to have_text("#{Date.current.year} Zoomora")
  end
end
