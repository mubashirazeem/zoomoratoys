# frozen_string_literal: true

require "rails_helper"

RSpec.describe Layout::WhatsappButtonComponent, type: :component do
  it "links to a WhatsApp chat with the support number, opening in a new tab" do
    render_inline(described_class.new)

    link = page.find("a[aria-label='Chat with us on WhatsApp']")
    expect(link[:href]).to eq("https://wa.me/971527225064")
    expect(link[:target]).to eq("_blank")
    expect(link[:rel]).to eq("noopener")
  end

  it "is fixed to the bottom-left corner" do
    render_inline(described_class.new)

    link = page.find("a[aria-label='Chat with us on WhatsApp']")
    expect(link[:class]).to include("fixed", "bottom-6", "left-6")
  end
end
