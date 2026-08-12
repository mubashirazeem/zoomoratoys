require "rails_helper"

RSpec.describe OrderMailer do
  let(:user) { create(:user, first_name: "Layla") }
  let(:product) { create(:product, name: "ATV 135cc") }
  let(:order) do
    create(:order, user: user, order_number: "ZMR-5000", total_cents: 10_500, subtotal_cents: 10_500).tap do |o|
      create(:line_item, order: o, product: product, quantity: 1, price_cents: 10_500)
    end
  end

  describe "#confirmation" do
    it "emails the customer with no Stripe attachment for a Pay on Delivery order" do
      mail = described_class.confirmation(order)

      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to eq("Order confirmed — ZMR-5000")
      expect(mail.attachments.map(&:filename)).to eq([ "logo.png" ])
      expect(mail.html_part.body).to include("ATV 135cc")
    end

    it "attaches the Stripe invoice PDF for a paid card order" do
      order.update!(payment_method: "card", status: "pending", stripe_invoice_id: "in_test_1")
      allow(Stripe::Invoice).to receive(:retrieve).with("in_test_1")
        .and_return(double("Stripe::Invoice", invoice_pdf: "https://files.stripe.com/invoice.pdf"))
      allow(URI).to receive(:parse).with("https://files.stripe.com/invoice.pdf")
        .and_return(double("URI", open: double("response", read: "%PDF-fake-bytes")))

      mail = described_class.confirmation(order)
      invoice_attachment = mail.attachments.find { |a| a.filename == "ZMR-5000-invoice.pdf" }

      expect(invoice_attachment).to be_present
      expect(invoice_attachment.body.raw_source).to eq("%PDF-fake-bytes")
    end

    it "still sends the confirmation when fetching the Stripe invoice fails" do
      order.update!(payment_method: "card", status: "pending", stripe_invoice_id: "in_test_1")
      allow(Stripe::Invoice).to receive(:retrieve).and_raise(Stripe::APIConnectionError.new("simulated"))

      mail = described_class.confirmation(order)

      expect(mail.attachments.map(&:filename)).to eq([ "logo.png" ])
      expect(mail.to).to eq([ user.email ])
    end

    it "still sends the confirmation when the invoice PDF download connection is reset mid-transfer" do
      order.update!(payment_method: "card", status: "pending", stripe_invoice_id: "in_test_1")
      allow(Stripe::Invoice).to receive(:retrieve).with("in_test_1")
        .and_return(double("Stripe::Invoice", invoice_pdf: "https://files.stripe.com/invoice.pdf"))
      allow(URI).to receive(:parse).with("https://files.stripe.com/invoice.pdf").and_raise(Errno::ECONNRESET)

      mail = described_class.confirmation(order)

      expect(mail.attachments.map(&:filename)).to eq([ "logo.png" ])
      expect(mail.to).to eq([ user.email ])
    end
  end

  describe "#shipped" do
    it "emails the customer" do
      mail = described_class.shipped(order)

      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to eq("Your order has shipped — ZMR-5000")
    end
  end

  describe "#refunded" do
    it "shows the refunded amount" do
      order.update!(payment_method: "card", status: "refunded", refunded_cents: 10_500)

      mail = described_class.refunded(order)

      expect(mail.subject).to eq("Your order has been refunded — ZMR-5000")
      expect(mail.html_part.body).to include("AED 105")
    end
  end

  describe "#cancelled" do
    it "emails the customer" do
      order.update!(status: "cancelled")

      mail = described_class.cancelled(order)

      expect(mail.subject).to eq("Your order has been cancelled — ZMR-5000")
    end
  end
end
