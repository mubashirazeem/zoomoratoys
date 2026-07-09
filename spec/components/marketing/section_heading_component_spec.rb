# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::SectionHeadingComponent, type: :component do
  it "renders the title without a view-all link by default" do
    render_inline(described_class.new(title: "Featured Picks"))

    expect(page).to have_css("h2", text: "Featured Picks")
    expect(page).not_to have_link
  end

  it "renders a view-all link when a url is given" do
    render_inline(described_class.new(title: "Electric Scooters", view_all_url: "/shop?category=electric-scooters"))

    expect(page).to have_link("View All", href: "/shop?category=electric-scooters")
  end

  it "allows overriding the view-all label" do
    render_inline(described_class.new(title: "Electric Scooters", view_all_url: "/shop", view_all_label: "See All Scooters"))

    expect(page).to have_link("See All Scooters")
  end

  it "renders extra content passed to the actions slot" do
    render_inline(described_class.new(title: "Best Sellers")) do |component|
      component.with_actions { "<button>Next</button>".html_safe }
    end

    expect(page).to have_button("Next")
  end
end
