require "rails_helper"

RSpec.describe Payments::Tamara::CheckEligibility, type: :model do
  it "returns true when Tamara reports the customer as eligible" do
    allow(Payments::Tamara).to receive(:post).and_return({ "is_eligible" => true })

    expect(described_class.call(amount_cents: 10_000, email: "layla@example.com")).to eq(true)
  end

  it "returns false when Tamara reports the customer as ineligible" do
    allow(Payments::Tamara).to receive(:post).and_return({ "is_eligible" => false })

    expect(described_class.call(amount_cents: 10_000, email: "layla@example.com")).to eq(false)
  end

  it "defaults to eligible (fail open) when the eligibility call itself fails — must not block checkout rendering" do
    allow(Payments::Tamara).to receive(:post).and_raise(Payments::ProviderError, "timeout")

    expect(described_class.call(amount_cents: 10_000, email: "layla@example.com")).to eq(true)
  end

  it "calls Tamara with a short timeout, not the default 10s used elsewhere" do
    expect(Payments::Tamara).to receive(:post).with(
      "/pre-checkout/v1/eligibility",
      { order: { amount: 100.0, currency: "AED" }, customer: { email: "layla@example.com" } },
      timeout: 0.2
    ).and_return({ "is_eligible" => true })

    described_class.call(amount_cents: 10_000, email: "layla@example.com")
  end

  it "sends order.amount as a real JSON number, not a string — Tamara's sandbox rejects a quoted amount as \"invalid json\"" do
    expect(Payments::Tamara).to receive(:post) do |_path, body, **|
      expect(body[:order][:amount]).to be_a(Numeric)
      { "is_eligible" => true }
    end

    described_class.call(amount_cents: 10_000, email: "layla@example.com")
  end
end
