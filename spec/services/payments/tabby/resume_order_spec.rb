require "rails_helper"

RSpec.describe Payments::Tabby::ResumeOrder do
  let(:user) { create(:user) }
  let(:order) do
    create(:order, user: user, payment_method: "tabby", status: "awaiting_payment",
                   tabby_payment_id: "pay_old", total_cents: 10_000)
  end

  def stub_tabby(old_payment_status:, close_status: 200)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      if req.path.include?("/close")
        instance_double(Net::HTTPResponse, body: "{}", is_a?: close_status == 200, code: close_status.to_s)
      elsif req.path == "/api/v2/payments/pay_old"
        instance_double(Net::HTTPResponse, body: { status: old_payment_status }.to_json, is_a?: true, code: "200")
      elsif req.method == "POST" && req.path == "/api/v2/checkout"
        instance_double(Net::HTTPResponse, body: {
          "payment" => { "id" => "pay_new" },
          "configuration" => { "available_products" => { "installments" => [ { "web_url" => "https://checkout.tabby.ai/pay_new" } ] } }
        }.to_json, is_a?: true, code: "200")
      else
        raise "unexpected request: #{req.method} #{req.path}"
      end
    end
  end

  it "closes the old payment first when it's still authorized but was never captured" do
    stub_tabby(old_payment_status: "AUTHORIZED")
    expect(Payments::Tabby).to receive(:close).with(payment_id: "pay_old").and_call_original

    url = described_class.call(
      order: order, user: user, success_url_for: ->(o) { "x" },
      cancel_url: "https://example.com/cancel", failure_url: "https://example.com/failure"
    )

    expect(url).to eq("https://checkout.tabby.ai/pay_new")
    expect(order.reload.tabby_payment_id).to eq("pay_new")
  end

  it "does not attempt to close the old payment when the customer never got far enough to authorize it" do
    stub_tabby(old_payment_status: "CREATED")
    expect(Payments::Tabby).not_to receive(:close)

    described_class.call(
      order: order, user: user, success_url_for: ->(o) { "x" },
      cancel_url: "https://example.com/cancel", failure_url: "https://example.com/failure"
    )
  end

  it "does not attempt to close an old payment that's already resolved (rejected/expired/closed)" do
    stub_tabby(old_payment_status: "REJECTED")
    expect(Payments::Tabby).not_to receive(:close)

    described_class.call(
      order: order, user: user, success_url_for: ->(o) { "x" },
      cancel_url: "https://example.com/cancel", failure_url: "https://example.com/failure"
    )
  end

  it "still resumes successfully even if closing the old payment fails — a stuck old payment must never block a customer who's trying to pay right now" do
    stub_tabby(old_payment_status: "AUTHORIZED", close_status: 500)

    url = described_class.call(
      order: order, user: user, success_url_for: ->(o) { "x" },
      cancel_url: "https://example.com/cancel", failure_url: "https://example.com/failure"
    )

    expect(url).to eq("https://checkout.tabby.ai/pay_new")
  end

  it "skips the close check entirely when there's no previous payment at all" do
    order.update!(tabby_payment_id: nil)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      instance_double(Net::HTTPResponse, body: {
        "payment" => { "id" => "pay_new" },
        "configuration" => { "available_products" => { "installments" => [ { "web_url" => "https://checkout.tabby.ai/pay_new" } ] } }
      }.to_json, is_a?: true, code: "200")
    end
    expect(Payments::Tabby).not_to receive(:get)
    expect(Payments::Tabby).not_to receive(:close)

    described_class.call(
      order: order, user: user, success_url_for: ->(o) { "x" },
      cancel_url: "https://example.com/cancel", failure_url: "https://example.com/failure"
    )
  end
end
