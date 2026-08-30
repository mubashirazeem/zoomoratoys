require "rails_helper"

RSpec.describe "TabbyWebhooks", type: :request do
  around do |example|
    original = ENV["TABBY_WEBHOOK_SECRET"]
    ENV["TABBY_WEBHOOK_SECRET"] = "test-secret-value"
    example.run
    ENV["TABBY_WEBHOOK_SECRET"] = original
  end

  let(:order) { create(:order, payment_method: "tabby", status: "awaiting_payment", tabby_payment_id: "pay_123") }

  it "rejects a request with no signature header at all" do
    post "/tabby/webhooks", params: { id: "pay_123", status: "authorized" }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a request with the wrong secret — this is the one thing standing between a real payment confirmation and anyone on the internet forging one" do
    post "/tabby/webhooks", params: { id: "pay_123", status: "authorized" }.to_json,
      headers: { "Content-Type" => "application/json", "X-Tabby-Webhook-Secret" => "wrong-guess" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts and processes a request with the correct secret" do
    order
    allow(Payments::Tabby).to receive(:get).and_return({ "status" => "AUTHORIZED" })
    allow(Payments::Tabby).to receive(:capture).and_return({})

    post "/tabby/webhooks", params: { id: "pay_123", status: "authorized" }.to_json,
      headers: { "Content-Type" => "application/json", "X-Tabby-Webhook-Secret" => "test-secret-value" }

    expect(response).to have_http_status(:ok)
    expect(order.reload.status).to eq("pending")
  end

  it "returns not_found (not ok) when the payment doesn't match any order yet — so Tabby retries instead of dropping the event, per its own webhook race-condition guidance" do
    post "/tabby/webhooks", params: { id: "no-such-payment", status: "authorized" }.to_json,
      headers: { "Content-Type" => "application/json", "X-Tabby-Webhook-Secret" => "test-secret-value" }

    expect(response).to have_http_status(:not_found)
  end

  it "returns unauthorized (not a crash) if the secret hasn't been configured yet" do
    ENV["TABBY_WEBHOOK_SECRET"] = nil

    post "/tabby/webhooks", params: { id: "pay_123", status: "authorized" }.to_json,
      headers: { "Content-Type" => "application/json", "X-Tabby-Webhook-Secret" => "anything" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns bad_request (not a crash) for a correctly-signed but unparseable body" do
    post "/tabby/webhooks", params: "not valid json",
      headers: { "Content-Type" => "application/json", "X-Tabby-Webhook-Secret" => "test-secret-value" }

    expect(response).to have_http_status(:bad_request)
  end
end
