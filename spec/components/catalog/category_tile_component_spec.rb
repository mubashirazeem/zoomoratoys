# frozen_string_literal: true

require "rails_helper"

RSpec.describe Catalog::CategoryTileComponent, type: :component do
  it "links to the shop page filtered by this category, with the name as real visible text" do
    category = build_stubbed(:category, name: "Electric Scooters", slug: "electric-scooters")

    render_inline(described_class.new(category: category))

    link = page.find_link("Electric Scooters")
    expect(link[:href]).to eq("/shop?category=electric-scooters")
  end

  it "shows the category description when present" do
    category = build_stubbed(:category, description: "Kick and seated electric scooters for every age.")

    render_inline(described_class.new(category: category))

    expect(page).to have_text("Kick and seated electric scooters for every age.")
  end
end
