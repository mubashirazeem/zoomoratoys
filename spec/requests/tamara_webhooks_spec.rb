require "rails_helper"

RSpec.describe "TamaraWebhooks", type: :request do
  let(:secret) { "test-notification-key" }

  around do |example|
    original = ENV["TAMARA_NOTIFICATION_KEY"]
    ENV["TAMARA_NOTIFICATION_KEY"] = secret
    example.run
    ENV["TAMARA_NOTIFICATION_KEY"] = original
  end

  let(:order) { create(:order, payment_method: "tamara", status: "awaiting_payment", tamara_order_id: "order_abc") }

  def valid_token
    JWT.encode({ iat: Time.now.to_i }, secret, "HS256")
  end

  it "rejects a request with no token at all" do
    post "/tamara/webhooks", params: { order_id: "order_abc", event_type: "order_approved" }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a forged token signed with the wrong secret — this is what stands between a real payment confirmation and anyone forging one" do
    forged = JWT.encode({ iat: Time.now.to_i }, "attacker-guessed-secret", "HS256")

    post "/tamara/webhooks?tamaraToken=#{forged}", params: { order_id: "order_abc", event_type: "order_approved" }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a garbage (non-JWT) token instead of raising a 500" do
    post "/tamara/webhooks?tamaraToken=not-a-real-jwt", params: { order_id: "order_abc", event_type: "order_approved" }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts a correctly-signed token as a query param" do
    order
    allow(Payments::Tamara).to receive(:post).and_return({})

    post "/tamara/webhooks?tamaraToken=#{valid_token}", params: { order_id: "order_abc", event_type: "order_approved" }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:ok)
    expect(order.reload.status).to eq("pending")
  end

  it "also accepts a correctly-signed token in the Authorization header" do
    order
    allow(Payments::Tamara).to receive(:post).and_return({})

    post "/tamara/webhooks", params: { order_id: "order_abc", event_type: "order_approved" }.to_json,
      headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{valid_token}" }

    expect(response).to have_http_status(:ok)
    expect(order.reload.status).to eq("pending")
  end

  it "returns unauthorized (not a crash) if the notification key hasn't been configured yet" do
    ENV["TAMARA_NOTIFICATION_KEY"] = nil

    post "/tamara/webhooks?tamaraToken=#{valid_token}", params: { order_id: "order_abc", event_type: "order_approved" }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns bad_request (not a crash) for a correctly-signed but unparseable body" do
    post "/tamara/webhooks?tamaraToken=#{valid_token}", params: "not valid json",
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
  end
end
