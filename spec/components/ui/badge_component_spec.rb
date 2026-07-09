# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::BadgeComponent, type: :component do
  Ui::BadgeComponent::VARIANTS.each_key do |variant|
    it "renders the #{variant} variant with its default label" do
      render_inline(described_class.new(variant: variant))

      expect(page).to have_text(Ui::BadgeComponent::VARIANTS.fetch(variant)[:label])
    end
  end

  it "allows overriding the label" do
    render_inline(described_class.new(variant: :sale, label: "40% Off"))

    expect(page).to have_text("40% Off")
  end

  it "raises for an unknown variant" do
    expect { described_class.new(variant: :mystery) }.to raise_error(ArgumentError)
  end
end
