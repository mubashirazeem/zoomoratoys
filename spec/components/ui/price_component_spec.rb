# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::PriceComponent, type: :component do
  it "renders a plain price" do
    render_inline(described_class.new(price_cents: 129_900))

    expect(page).to have_text("AED 1,299")
    expect(page).not_to have_css("span.line-through")
  end

  it "renders a strikethrough compare-at price when on sale" do
    render_inline(described_class.new(price_cents: 89_900, compare_at_cents: 129_900))

    expect(page).to have_text("AED 899")
    expect(page).to have_css("span.line-through", text: "AED 1,299")
  end

  it "does not show a compare-at price when it is not higher than the price" do
    render_inline(described_class.new(price_cents: 129_900, compare_at_cents: 129_900))

    expect(page).not_to have_css("span.line-through")
  end
end
