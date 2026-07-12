# frozen_string_literal: true

require "rails_helper"

RSpec.describe Catalog::ProductGalleryComponent, type: :component do
  it "renders the product's category photo with its name as the accessible alt text" do
    product = build_stubbed(:product, name: "Summit E-Trail 27.5", placeholder_key: "bicycle")

    render_inline(described_class.new(product: product))

    # Scoped to the main image: the gallery also renders four thumbnail
    # <img> tags alongside it, so an unscoped find("img") is ambiguous.
    image = page.find("[data-gallery-target='main']")
    expect(image["alt"]).to eq("Summit E-Trail 27.5")
    expect(image["src"]).to include("category-bicycle")
  end
end
