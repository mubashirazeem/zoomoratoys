require "rails_helper"

RSpec.describe ContactMailer do
  let(:contact_message) { create(:contact_message, name: "Omar", email: "omar@example.com", subject: "Delivery question") }

  describe "#acknowledgement" do
    it "replies to the person who submitted the form" do
      mail = described_class.acknowledgement(contact_message)

      expect(mail.to).to eq([ "omar@example.com" ])
      expect(mail.html_part.body).to include("Delivery question")
    end
  end

  describe "#new_submission" do
    it "notifies the sales inbox with reply-to set to the customer" do
      mail = described_class.new_submission(contact_message)

      expect(mail.to).to eq([ "sales@zoomora.com" ])
      expect(mail.reply_to).to eq([ "omar@example.com" ])
      expect(mail.subject).to eq("New contact form message: Delivery question")
    end
  end
end
