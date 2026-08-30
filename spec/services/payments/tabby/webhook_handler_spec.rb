require "rails_helper"

RSpec.describe Payments::Tabby::WebhookHandler, type: :model do
  # Two distinct calls now happen per authorized webhook — GET
  # /payments/{id} (verify) then POST .../captures (capture) — so the stub
  # has to respond differently per request path, not return one canned
  # response for everything.
  def stub_tabby_capture(status: 200, verified_status: "AUTHORIZED", captures: [])
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      if req.path.include?("/captures")
        instance_double(Net::HTTPResponse, body: "{}", is_a?: status == 200, code: status.to_s)
      else
        instance_double(Net::HTTPResponse, body: { status: verified_status, captures: captures }.to_json, is_a?: true, code: "200")
      end
    end
  end

  let(:order) { create(:order, payment_method: "tabby", status: "awaiting_payment", tabby_payment_id: "pay_123", total_cents: 10_000) }

  describe "authorized" do
    it "captures the full amount and marks the order paid" do
      stub_tabby_capture
      order

      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.to change { order.reload.status }.from("awaiting_payment").to("pending")
    end

    it "sends the confirmation and admin-alert emails exactly once" do
      stub_tabby_capture
      order

      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.to have_enqueued_mail(OrderMailer, :confirmation).and have_enqueued_mail(AdminMailer, :new_order)
    end

    it "is safe to run twice on a redelivered webhook — does not capture or email again" do
      stub_tabby_capture
      order
      described_class.call({ "id" => "pay_123", "status" => "authorized" })

      expect(Net::HTTP).to receive(:start).exactly(0).times
      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.not_to have_enqueued_mail(OrderMailer, :confirmation)
    end

    it "does not capture — leaves the order awaiting_payment — if GET /payments/{id} doesn't independently confirm AUTHORIZED" do
      stub_tabby_capture(verified_status: "REJECTED")
      order

      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.not_to change { order.reload.status }
    end

    it "leaves the order awaiting_payment (not silently paid) if the capture call itself fails" do
      stub_tabby_capture(status: 500)
      order

      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.not_to change { order.reload.status }
    end

    it "leaves the order awaiting_payment (not a crashed webhook) if the capture call hits a network failure, not an HTTP error response" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
      order

      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.not_to change { order.reload.status }
    end

    it "does nothing for an unknown payment id, without raising, and reports :order_not_found so the controller can ask Tabby to retry" do
      result = nil
      expect { result = described_class.call({ "id" => "not-a-real-payment", "status" => "authorized" }) }.not_to raise_error
      expect(result).to eq(:order_not_found)
    end

    it "treats CLOSED as good enough — a closed event can be delivered before its own authorized one, and must not leave the order stuck" do
      stub_tabby_capture(verified_status: "CLOSED", captures: [ { id: "cap_1", amount: "100" } ])
      order

      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.to change { order.reload.status }.from("awaiting_payment").to("pending")
    end

    it "does not call capture again when Tabby's own captures array is already non-empty — a confirmation, not a request to capture" do
      stub_tabby_capture(captures: [ { id: "cap_1", amount: "100" } ])
      order

      expect(Payments::Tabby).not_to receive(:capture)

      described_class.call({ "id" => "pay_123", "status" => "authorized" })

      expect(order.reload.status).to eq("pending")
    end

    it "does call capture when Tabby's captures array is empty" do
      stub_tabby_capture
      order

      expect(Payments::Tabby).to receive(:capture).with(payment_id: "pay_123", amount_cents: order.total_cents, reference_id: order.order_number)

      described_class.call({ "id" => "pay_123", "status" => "authorized" })
    end

    it "retries the capture once, with the same reference_id, after a timeout — and marks the order paid once the retry lands" do
      order
      capture_attempts = 0
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) do |req|
        if req.path.include?("/captures")
          capture_attempts += 1
          raise Net::ReadTimeout if capture_attempts == 1
          instance_double(Net::HTTPResponse, body: "{}", is_a?: true, code: "200")
        else
          instance_double(Net::HTTPResponse, body: { status: "AUTHORIZED", captures: [] }.to_json, is_a?: true, code: "200")
        end
      end

      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.to change { order.reload.status }.from("awaiting_payment").to("pending")

      expect(capture_attempts).to eq(2) # one timeout, one retry — a real bug once had this backwards and skipped the retry entirely
    end

    it "does not retry the capture at all if the timed-out attempt actually landed" do
      order
      capture_attempts = 0
      get_calls = 0
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) do |req|
        if req.path.include?("/captures")
          capture_attempts += 1
          raise Net::ReadTimeout
        else
          get_calls += 1
          # First GET (pre-capture verification) sees nothing yet; the
          # second (the post-timeout re-check) sees the capture landed.
          captures = get_calls == 1 ? [] : [ { id: "cap_1", amount: "100" } ]
          instance_double(Net::HTTPResponse, body: { status: "AUTHORIZED", captures: captures }.to_json, is_a?: true, code: "200")
        end
      end

      expect {
        described_class.call({ "id" => "pay_123", "status" => "authorized" })
      }.to change { order.reload.status }.from("awaiting_payment").to("pending")

      expect(capture_attempts).to eq(1) # never retried — a real bug once re-raised here and left the order awaiting_payment forever
    end
  end

  describe "rejected/expired" do
    it "restores stock and cancels the order" do
      product = create(:product, stock_quantity: 3)
      order_with_item = create(:order, payment_method: "tabby", status: "awaiting_payment", tabby_payment_id: "pay_456")
      create(:line_item, order: order_with_item, product: product, quantity: 2)
      product.update!(stock_quantity: 1) # simulate the reservation already decremented

      described_class.call({ "id" => "pay_456", "status" => "rejected" })

      expect(order_with_item.reload.status).to eq("cancelled")
      expect(product.reload.stock_quantity).to eq(3)
    end

    it "does not touch an order that's already past awaiting_payment" do
      paid_order = create(:order, payment_method: "tabby", status: "pending", tabby_payment_id: "pay_789")

      described_class.call({ "id" => "pay_789", "status" => "expired" })

      expect(paid_order.reload.status).to eq("pending")
    end

    it "does nothing for an unknown payment id, without raising, and reports :order_not_found" do
      result = nil
      expect { result = described_class.call({ "id" => "not-a-real-payment", "status" => "rejected" }) }.not_to raise_error
      expect(result).to eq(:order_not_found)
    end
  end

  describe "closed" do
    it "does nothing — capture already recorded it, no further action needed" do
      order

      expect {
        described_class.call({ "id" => "pay_123", "status" => "closed" })
      }.not_to change { order.reload.status }
    end
  end

  describe "an unrecognized status" do
    it "does nothing, without raising" do
      order

      expect {
        described_class.call({ "id" => "pay_123", "status" => "some_future_tabby_status" })
      }.not_to raise_error
      expect(order.reload.status).to eq("awaiting_payment")
    end
  end
end
