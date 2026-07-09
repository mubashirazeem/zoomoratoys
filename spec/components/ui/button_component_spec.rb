# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::ButtonComponent, type: :component do
  it "renders a real button by default" do
    render_inline(described_class.new) { "Add to Cart" }

    expect(page).to have_button("Add to Cart")
  end

  it "renders a link when href is given" do
    render_inline(described_class.new(href: "/shop")) { "Shop Now" }

    expect(page).to have_link("Shop Now", href: "/shop")
  end

  it "renders a disabled button that cannot be activated" do
    render_inline(described_class.new(disabled: true)) { "Add to Cart" }

    expect(page).to have_button("Add to Cart", disabled: true)
  end

  it "marks a disabled link as non-interactive via aria-disabled and a removed tab stop" do
    render_inline(described_class.new(href: "/checkout", disabled: true)) { "Checkout" }

    link = page.find("a", text: "Checkout")
    expect(link["aria-disabled"]).to eq("true")
    expect(link["tabindex"]).to eq("-1")
  end

  it "raises for an unknown variant" do
    expect { described_class.new(variant: :mystery) }.to raise_error(ArgumentError)
  end

  it "raises for an unknown size" do
    expect { described_class.new(size: :mystery) }.to raise_error(ArgumentError)
  end
end
