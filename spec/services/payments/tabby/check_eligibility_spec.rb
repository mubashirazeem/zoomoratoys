require "rails_helper"

RSpec.describe Payments::Tabby::CheckEligibility, type: :model do
  it "skips the call entirely and returns eligible when there's no phone number yet" do
    expect(Payments::Tabby).not_to receive(:post)

    result = described_class.call(amount_cents: 10_000, email: "layla@example.com", phone: nil)

    expect(result).to be_nil
  end

  it "returns nil (eligible) when Tabby's pre-scoring approves the customer" do
    allow(Payments::Tabby).to receive(:post).and_return({ "status" => "created" })

    result = described_class.call(amount_cents: 10_000, email: "layla@example.com", phone: "+971501234567")

    expect(result).to be_nil
  end

  it "returns the rejection message, not just a boolean, when pre-scoring rejects the customer" do
    allow(Payments::Tabby).to receive(:post).and_return({
      "status" => "rejected",
      "configuration" => { "products" => { "installments" => { "is_available" => false, "rejection_reason" => "order_amount_too_high" } } }
    })

    result = described_class.call(amount_cents: 10_000, email: "layla@example.com", phone: "+971501234567")

    expect(result).to eq("This order total is too high for Tabby — please choose a different payment method.")
  end

  it "degrades to eligible (nil), never raising, when Tabby is unreachable" do
    allow(Payments::Tabby).to receive(:post).and_raise(Payments::ProviderError, "timeout")

    result = described_class.call(amount_cents: 10_000, email: "layla@example.com", phone: "+971501234567")

    expect(result).to be_nil
  end
end
