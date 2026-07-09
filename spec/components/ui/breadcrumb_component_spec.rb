# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::BreadcrumbComponent, type: :component do
  let(:items) do
    [
      { label: "Home", url: "/" },
      { label: "Shop", url: "/shop" },
      { label: "Trailhawk Off-Road Scooter" }
    ]
  end

  it "links every item except the last" do
    render_inline(described_class.new(items: items))

    expect(page).to have_link("Home", href: "/")
    expect(page).to have_link("Shop", href: "/shop")
    expect(page).not_to have_link("Trailhawk Off-Road Scooter")
  end

  it "marks the last item as the current page" do
    render_inline(described_class.new(items: items))

    expect(page).to have_css("[aria-current='page']", text: "Trailhawk Off-Road Scooter")
  end
end
