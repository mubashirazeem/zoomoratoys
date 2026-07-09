# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::TrustBadgeComponent, type: :component do
  Marketing::TrustBadgeComponent::ICONS.each do |icon|
    it "renders the #{icon} icon with a title and description" do
      render_inline(described_class.new(icon: icon, title: "Fast Delivery", description: "Delivered across the UAE."))

      expect(page).to have_css("h3", text: "Fast Delivery")
      expect(page).to have_text("Delivered across the UAE.")
    end
  end

  it "raises for an unknown icon" do
    expect { described_class.new(icon: "rocket", title: "x", description: "y") }.to raise_error(ArgumentError)
  end
end
