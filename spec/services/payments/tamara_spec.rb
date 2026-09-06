require "rails_helper"

RSpec.describe Payments::Tamara do
  around do |example|
    original = ENV["TAMARA_API_TOKEN"]
    example.run
    ENV["TAMARA_API_TOKEN"] = original
  end

  it "does not raise an unrescued KeyError when TAMARA_API_TOKEN is missing — CheckEligibility runs on every checkout page load regardless of payment method, so a raw KeyError here would 500 the whole page for every customer" do
    ENV.delete("TAMARA_API_TOKEN")
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(
      instance_double(Net::HTTPResponse, body: { "message" => "Unauthorized" }.to_json, is_a?: false, code: "401")
    )

    expect { described_class.get("/orders/order_123") }.to raise_error(Payments::ProviderError)
  end

  it "sends a blank bearer token (not a crash) when TAMARA_API_TOKEN is missing" do
    ENV.delete("TAMARA_API_TOKEN")
    sent_header = nil
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      sent_header = req["Authorization"]
      instance_double(Net::HTTPResponse, body: "{}", is_a?: true, code: "200")
    end

    described_class.get("/orders/order_123")

    expect(sent_header).to eq("Bearer ")
  end
end
