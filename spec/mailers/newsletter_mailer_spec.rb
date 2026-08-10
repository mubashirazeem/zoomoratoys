require "rails_helper"

RSpec.describe NewsletterMailer do
  describe "#welcome" do
    it "emails the new subscriber" do
      subscriber = create(:newsletter_subscriber, email: "fan@example.com")

      mail = described_class.welcome(subscriber)

      expect(mail.to).to eq([ "fan@example.com" ])
      expect(mail.subject).to eq("Welcome to Zoomora Toys")
    end
  end
end
