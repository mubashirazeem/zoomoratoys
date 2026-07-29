# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::PromoMarqueeComponent, type: :component do
  it "renders every promotional message" do
    render_inline(described_class.new)

    Marketing::PromoMarqueeComponent::MESSAGES.each do |message|
      expect(page).to have_text(message)
    end
  end

  it "duplicates the message set once for a seamless scroll loop" do
    render_inline(described_class.new)

    expect(page).to have_text(Marketing::PromoMarqueeComponent::MESSAGES.first, count: 2)
  end

  it "hides the decorative, moving track from screen readers — its content already exists as static, accessible text elsewhere on the page" do
    render_inline(described_class.new)

    expect(page).to have_css("[aria-hidden='true']")
  end
end
