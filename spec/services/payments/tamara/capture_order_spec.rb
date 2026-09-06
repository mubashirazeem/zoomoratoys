require "rails_helper"

RSpec.describe Payments::Tamara::CaptureOrder do
  def stub_tamara_capture
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      instance_double(Net::HTTPResponse, body: { "status" => "fully_captured" }.to_json, is_a?: true, code: "200")
    end
    http
  end

  it "sends the real order total and Tamara's own example shipping_info shape to the Capture API" do
    sent_path = nil
    sent_body = nil
    http = stub_tamara_capture
    allow(http).to receive(:request) do |req|
      sent_path = req.path
      sent_body = JSON.parse(req.body)
      instance_double(Net::HTTPResponse, body: { "status" => "fully_captured" }.to_json, is_a?: true, code: "200")
    end
    order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_123", total_cents: 15_000)

    described_class.call(order: order)

    expect(sent_path).to eq("/payments/capture")
    expect(sent_body["order_id"]).to eq("order_123")
    expect(sent_body["total_amount"]).to eq("amount" => 150.0, "currency" => "AED")
    expect(sent_body["shipping_info"]["shipping_company"]).to eq("N/A")
    expect(sent_body["shipping_info"]["shipped_at"]).to be_present
  end

  it "raises Payments::ProviderError (not a crash) if Tamara rejects the capture" do
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(
      instance_double(Net::HTTPResponse, body: { "message" => "Order not authorised" }.to_json, is_a?: false, code: "409")
    )
    order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_123", total_cents: 15_000)

    expect { described_class.call(order: order) }.to raise_error(Payments::ProviderError)
  end
end
