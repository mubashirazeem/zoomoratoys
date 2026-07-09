# frozen_string_literal: true

require "rails_helper"

RSpec.describe Catalog::ProductGalleryComponent, type: :component do
  it "renders the product's category photo with its name as the accessible alt text" do
    product = build_stubbed(:product, name: "Summit E-Trail 27.5", placeholder_key: "bicycle")

    render_inline(described_class.new(product: product))

    image = page.find("img")
    expect(image["alt"]).to eq("Summit E-Trail 27.5")
    expect(image["src"]).to include("category-bicycle")
  end
end
