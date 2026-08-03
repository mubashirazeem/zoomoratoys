# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::CategoryRailComponent, type: :component do
  it "renders a tile for every category" do
    categories = build_stubbed_list(:category, 3)

    render_inline(described_class.new(title: "Explore Categories", categories: categories))

    categories.each { |category| expect(page).to have_text(category.name) }
  end

  it "renders the section title" do
    render_inline(described_class.new(title: "Explore Categories", categories: []))

    expect(page).to have_css("h2", text: "Explore Categories")
  end

  it "renders prev/next carousel controls" do
    render_inline(described_class.new(title: "Explore Categories", categories: []))

    expect(page).to have_css("button[aria-label='Previous']")
    expect(page).to have_css("button[aria-label='Next']")
  end

  it "renders a view-all link when given" do
    render_inline(described_class.new(title: "Explore Categories", categories: [], view_all_url: "/categories"))

    expect(page).to have_link("View All", href: "/categories")
  end
end
