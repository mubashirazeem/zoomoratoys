# frozen_string_literal: true

require "rails_helper"

RSpec.describe Catalog::ProductVariantsComponent, type: :component do
  it "renders a real, selectable color swatch group" do
    product = build_stubbed(:product, id: 1)

    render_inline(described_class.new(product: product))

    expect(page).to have_css("[data-controller='variant-selector']", minimum: 1)
    expect(page).to have_css("button[data-action='variant-selector#select'][aria-label^='Color:']", minimum: 3)
  end

  it "renders Size and Material groups" do
    product = build_stubbed(:product, id: 1)

    render_inline(described_class.new(product: product))

    expect(page).to have_text("Size:")
    expect(page).to have_text("Material:")
  end

  it "is deterministic — the same product renders the same options every time" do
    product = build_stubbed(:product, id: 42)

    first_render = render_inline(described_class.new(product: product)).to_html
    second_render = render_inline(described_class.new(product: product)).to_html

    expect(first_render).to eq(second_render)
  end
end
