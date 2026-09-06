require "rails_helper"

RSpec.describe Payments::Tamara::WebhookHandler, type: :model do
  def stub_tamara_authorise(status: 200)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    response = instance_double(Net::HTTPResponse, body: "{}", is_a?: status == 200, code: status.to_s)
    allow(http).to receive(:request).and_return(response)
  end

  let(:order) { create(:order, payment_method: "tamara", status: "awaiting_payment", tamara_order_id: "order_abc", total_cents: 10_000) }

  describe "order_approved" do
    it "authorises the order and marks it paid" do
      stub_tamara_authorise
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_approved" })
      }.to change { order.reload.status }.from("awaiting_payment").to("pending")
    end

    it "sends the confirmation and admin-alert emails exactly once" do
      stub_tamara_authorise
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_approved" })
      }.to have_enqueued_mail(OrderMailer, :confirmation).and have_enqueued_mail(AdminMailer, :new_order)
    end

    it "is safe to run twice on a redelivered webhook" do
      stub_tamara_authorise
      order
      described_class.call({ "order_id" => "order_abc", "event_type" => "order_approved" })

      expect(Net::HTTP).to receive(:start).exactly(0).times
      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_approved" })
      }.not_to have_enqueued_mail(OrderMailer, :confirmation)
    end

    it "leaves the order awaiting_payment if the authorise call itself fails" do
      stub_tamara_authorise(status: 500)
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_approved" })
      }.not_to change { order.reload.status }
    end

    it "leaves the order awaiting_payment if the authorise call hits a network failure, not an HTTP error response" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_approved" })
      }.not_to change { order.reload.status }
    end

    it "does nothing for an unknown order id, without raising" do
      expect { described_class.call({ "order_id" => "not-real", "event_type" => "order_approved" }) }.not_to raise_error
    end
  end

  describe "order_authorised — Tamara's own auto-authorisation feature can send this as the only success webhook, without ever sending order_approved first" do
    def stub_tamara_get_status(status)
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      response = instance_double(Net::HTTPResponse, body: { "status" => status }.to_json, is_a?: true, code: "200")
      allow(http).to receive(:request).and_return(response)
    end

    it "verifies via GET (never trusts the webhook payload alone) and marks the order paid, without calling /authorise again" do
      stub_tamara_get_status("authorised")
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_authorised" })
      }.to change { order.reload.status }.from("awaiting_payment").to("pending")
    end

    it "does not call POST /orders/{id}/authorise — Tamara already authorised it itself" do
      stub_tamara_get_status("authorised")
      order

      expect(Net::HTTP::Post).not_to receive(:new)
      described_class.call({ "order_id" => "order_abc", "event_type" => "order_authorised" })
    end

    it "also accepts fully_captured/partially_captured — at least as final as authorised" do
      stub_tamara_get_status("fully_captured")
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_authorised" })
      }.to change { order.reload.status }.to("pending")
    end

    it "leaves the order awaiting_payment if GET verification doesn't independently confirm it" do
      stub_tamara_get_status("new")
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_authorised" })
      }.not_to change { order.reload.status }
    end

    it "sends the confirmation and admin-alert emails exactly once" do
      stub_tamara_get_status("authorised")
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_authorised" })
      }.to have_enqueued_mail(OrderMailer, :confirmation).and have_enqueued_mail(AdminMailer, :new_order)
    end

    it "is safe to run twice on a redelivered webhook, and safe if it arrives after order_approved already processed this same order" do
      stub_tamara_authorise
      order
      described_class.call({ "order_id" => "order_abc", "event_type" => "order_approved" })

      expect(Net::HTTP).to receive(:start).exactly(0).times
      expect {
        described_class.call({ "order_id" => "order_abc", "event_type" => "order_authorised" })
      }.not_to have_enqueued_mail(OrderMailer, :confirmation)
    end

    it "does nothing for an unknown order id, without raising" do
      expect { described_class.call({ "order_id" => "not-real", "event_type" => "order_authorised" }) }.not_to raise_error
    end
  end

  describe "order_declined/order_expired/order_canceled" do
    it "restores stock and cancels the order" do
      product = create(:product, stock_quantity: 3)
      order_with_item = create(:order, payment_method: "tamara", status: "awaiting_payment", tamara_order_id: "order_xyz")
      create(:line_item, order: order_with_item, product: product, quantity: 2)
      product.update!(stock_quantity: 1)

      described_class.call({ "order_id" => "order_xyz", "event_type" => "order_declined" })

      expect(order_with_item.reload.status).to eq("cancelled")
      expect(product.reload.stock_quantity).to eq(3)
    end
  end

  describe "order_refunded" do
    def stub_tamara_get_refunded_amount(amount)
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      response = instance_double(Net::HTTPResponse, body: { "refunded_amount" => { "amount" => amount, "currency" => "AED" } }.to_json, is_a?: true, code: "200")
      allow(http).to receive(:request).and_return(response)
    end

    it "marks the order fully refunded and restores stock when GET verification confirms the refunded amount covers the whole order" do
      stub_tamara_get_refunded_amount(100.00)
      product = create(:product, stock_quantity: 3)
      refunded_order = create(:order, payment_method: "tamara", status: "pending", tamara_order_id: "order_ref", total_cents: 10_000)
      create(:line_item, order: refunded_order, product: product, quantity: 1)
      product.update!(stock_quantity: 2)

      described_class.call({ "order_id" => "order_ref", "event_type" => "order_refunded" })

      refunded_order.reload
      expect(refunded_order.status).to eq("refunded")
      expect(refunded_order.refunded_cents).to eq(10_000)
      expect(product.reload.stock_quantity).to eq(3)
    end

    it "records a partial refund without marking the order fully refunded or restoring stock — deliberately never trusts the webhook's own payload for the amount (two Tamara doc pages disagree on what that field even means), only the GET-verified order-level refunded_amount" do
      stub_tamara_get_refunded_amount(40.00)
      product = create(:product, stock_quantity: 3)
      order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_partial", total_cents: 10_000)
      create(:line_item, order: order, product: product, quantity: 1)
      product.update!(stock_quantity: 2)

      described_class.call({ "order_id" => "order_partial", "event_type" => "order_refunded" })

      order.reload
      expect(order.status).to eq("processing") # not "refunded" — only part of the money came back
      expect(order.refunded_cents).to eq(4_000)
      expect(order.partially_refunded?).to be true
      expect(product.reload.stock_quantity).to eq(2) # unchanged — a partial refund isn't a returned item
    end

    it "does not double-count a redelivered webhook reporting the same cumulative refunded amount" do
      stub_tamara_get_refunded_amount(40.00)
      order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_redeliver", total_cents: 10_000, refunded_cents: 4_000)

      described_class.call({ "order_id" => "order_redeliver", "event_type" => "order_refunded" })

      expect(order.reload.refunded_cents).to eq(4_000)
    end

    it "correctly moves from a partial to a fully-refunded state when a second, larger cumulative amount is confirmed" do
      stub_tamara_get_refunded_amount(100.00)
      product = create(:product, stock_quantity: 3)
      order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_topup", total_cents: 10_000, refunded_cents: 4_000)
      create(:line_item, order: order, product: product, quantity: 1)
      product.update!(stock_quantity: 2)

      described_class.call({ "order_id" => "order_topup", "event_type" => "order_refunded" })

      order.reload
      expect(order.status).to eq("refunded")
      expect(order.refunded_cents).to eq(10_000)
      expect(product.reload.stock_quantity).to eq(3)
    end

    it "logs and does nothing, without raising, if GET verification itself fails" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
      order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_malformed", total_cents: 10_000)

      expect {
        described_class.call({ "order_id" => "order_malformed", "event_type" => "order_refunded" })
      }.not_to raise_error

      expect(order.reload.refunded_cents).to eq(0)
    end

    it "logs and does nothing, without raising, if GET verification succeeds but has no refunded_amount.amount" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request).and_return(instance_double(Net::HTTPResponse, body: "{}", is_a?: true, code: "200"))
      order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_empty", total_cents: 10_000)

      expect {
        described_class.call({ "order_id" => "order_empty", "event_type" => "order_refunded" })
      }.not_to raise_error

      expect(order.reload.refunded_cents).to eq(0)
    end

    it "is a no-op once the order is already fully refunded — does not even call GET" do
      order = create(:order, payment_method: "tamara", status: "refunded", tamara_order_id: "order_done", total_cents: 10_000, refunded_cents: 10_000)

      expect(Net::HTTP).not_to receive(:start)
      described_class.call({ "order_id" => "order_done", "event_type" => "order_refunded" })
    end
  end

  describe "unrecognized event_type" do
    it "does not raise" do
      expect { described_class.call({ "order_id" => "order_abc", "event_type" => "something_new" }) }.not_to raise_error
    end
  end

  describe "payload with no event_type at all — the real shape confirmed live from an organic (non-curl) webhook delivery to the per-order merchant_url.notification callback" do
    it "falls back to order_status and still authorises + marks the order paid, exactly matching the real payload Tamara delivered: {order_id, order_reference_id, order_status: 'approved', data: []}" do
      stub_tamara_authorise
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "order_reference_id" => "ZMR-1", "order_status" => "approved", "data" => [] })
      }.to change { order.reload.status }.from("awaiting_payment").to("pending")
    end

    it "falls back to order_status 'authorised' via the same GET-verify path as a real order_authorised event" do
      def stub_tamara_get_status(status)
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:start).and_yield(http)
        response = instance_double(Net::HTTPResponse, body: { "status" => status }.to_json, is_a?: true, code: "200")
        allow(http).to receive(:request).and_return(response)
      end
      stub_tamara_get_status("authorised")
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "order_status" => "authorised" })
      }.to change { order.reload.status }.from("awaiting_payment").to("pending")
    end

    it "falls back to order_status for a decline and restores stock" do
      product = create(:product, stock_quantity: 3)
      order_with_item = create(:order, payment_method: "tamara", status: "awaiting_payment", tamara_order_id: "order_xyz")
      create(:line_item, order: order_with_item, product: product, quantity: 2)
      product.update!(stock_quantity: 1)

      described_class.call({ "order_id" => "order_xyz", "order_status" => "declined" })

      expect(order_with_item.reload.status).to eq("cancelled")
      expect(product.reload.stock_quantity).to eq(3)
    end

    it "logs and does nothing, without raising, when order_status itself is also missing or unrecognized" do
      order

      expect {
        described_class.call({ "order_id" => "order_abc", "data" => [] })
      }.not_to raise_error
      expect(order.reload.status).to eq("awaiting_payment")
    end
  end
end
