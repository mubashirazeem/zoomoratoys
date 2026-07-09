# frozen_string_literal: true

require "rails_helper"

RSpec.describe Layout::MobileNavComponent, type: :component do
  let(:items) do
    [
      { label: "Home", url: "/" },
      { label: "Shop", url: "/shop" }
    ]
  end

  it "renders every given nav item" do
    render_inline(described_class.new(items: items))

    expect(page).to have_link("Home", href: "/")
    expect(page).to have_link("Shop", href: "/shop")
  end

  it "renders as a labeled, initially-hidden dialog with a close control" do
    render_inline(described_class.new(items: items))

    dialog = page.find("[role='dialog']", visible: :all)
    expect(dialog["aria-modal"]).to eq("true")
    expect(dialog["aria-label"]).to eq("Menu")
    expect(dialog[:class]).to include("hidden")
    expect(page).to have_css("button[aria-label='Close menu']", visible: :all)
  end
end
