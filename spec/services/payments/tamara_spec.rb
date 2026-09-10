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

  describe ".production? and .widget_script_url" do
    it "is sandbox by default (no TAMARA_BASE_URL), and the widget loads from the sandbox CDN" do
      allow(described_class).to receive(:base_url).and_return("https://api-sandbox.tamara.co")

      expect(described_class.production?).to be(false)
      expect(described_class.widget_script_url).to eq("https://cdn-sandbox.tamara.co/widget-v2/tamara-widget.js")
    end

    it "is production only when TAMARA_BASE_URL is the real host, and the widget then loads from the production CDN" do
      allow(described_class).to receive(:base_url).and_return("https://api.tamara.co")

      expect(described_class.production?).to be(true)
      expect(described_class.widget_script_url).to eq("https://cdn.tamara.co/widget-v2/tamara-widget.js")
    end
  end

  describe ".available?" do
    it "is true on dev/staging regardless of which host TAMARA_BASE_URL points at (sandbox is correct there)" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("staging"))
      allow(described_class).to receive(:base_url).and_return("https://api-sandbox.tamara.co")

      expect(described_class.available?).to be(true)
    end

    it "is false in production while still on a sandbox host — no sandbox key on the live site" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      allow(described_class).to receive(:base_url).and_return("https://api-sandbox.tamara.co")

      expect(described_class.available?).to be(false)
    end

    it "is true in production once TAMARA_BASE_URL is genuinely the production host" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      allow(described_class).to receive(:base_url).and_return("https://api.tamara.co")

      expect(described_class.available?).to be(true)
    end
  end
end
