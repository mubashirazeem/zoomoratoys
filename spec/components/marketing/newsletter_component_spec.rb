# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::NewsletterComponent, type: :component do
  it "renders the title and description" do
    render_inline(described_class.new(title: "Join the Adventure", description: "Get the latest offers."))

    expect(page).to have_css("h2", text: "Join the Adventure")
    expect(page).to have_text("Get the latest offers.")
  end

  it "renders a working subscribe form posting to the newsletter endpoint" do
    render_inline(described_class.new)

    expect(page).to have_css("form[action='/newsletter'][method='post']")
    expect(page).to have_field("Email address", type: "email")
    expect(page).to have_button("Subscribe")
  end
end
