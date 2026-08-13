# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::CustomerHighlightsComponent, type: :component do
  it "does not render when there are no highlights yet" do
    render_inline(described_class.new(highlights: CustomerHighlight.none))

    expect(page).to have_no_css("section")
  end

  it "shows the customer name, quote, and star rating" do
    highlight = create(:customer_highlight, customer_name: "Ahmed R.", quote: "Great bike!", rating: 4)

    render_inline(described_class.new(highlights: CustomerHighlight.where(id: highlight.id)))

    expect(page).to have_css("section")
    expect(page).to have_text("Happy Customers")
    expect(page).to have_text("Ahmed R.")
    expect(page).to have_text("Great bike!")
    expect(page.all("svg.text-red-600").size).to eq(4)
  end

  it "renders without a photo just fine — a text-only Google review" do
    highlight = create(:customer_highlight)

    render_inline(described_class.new(highlights: CustomerHighlight.where(id: highlight.id)))

    expect(page).to have_no_css("img")
  end

  it "renders the attached photo when present" do
    highlight = create(:customer_highlight)
    highlight.photo.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/sample_product_image.jpg")),
      filename: "sample_product_image.jpg",
      content_type: "image/jpeg"
    )

    render_inline(described_class.new(highlights: CustomerHighlight.where(id: highlight.id)))

    expect(page).to have_css("img")
  end
end
