require "rails_helper"

RSpec.describe AdminMailer do
  describe "#new_order" do
    it "notifies the sales inbox with the order total" do
      user = create(:user, first_name: "Layla", last_name: "Ahmed")
      order = create(:order, user: user, order_number: "ZMR-5001", total_cents: 4_949)

      mail = described_class.new_order(order)

      expect(mail.to).to eq([ "sales@zoomora.com" ])
      expect(mail.subject).to eq("New order — ZMR-5001 (AED 49)")
      expect(mail.html_part.body).to include("Layla Ahmed")
    end
  end
end
