require "rails_helper"

RSpec.describe "Stripe webhooks", type: :request do
  def post_signed_event(type, object_attrs)
    payload = { id: "evt_test", type: type, data: { object: object_attrs } }.to_json
    timestamp = Time.now.to_i
    signed_payload = "#{timestamp}.#{payload}"
    signature = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("STRIPE_WEBHOOK_SECRET"), signed_payload)

    post "/stripe/webhooks",
      params: payload,
      headers: { "Content-Type" => "application/json", "Stripe-Signature" => "t=#{timestamp},v1=#{signature}" }
  end

  it "accepts a validly-signed event and processes it" do
    allow(Stripe::Invoice).to receive(:retrieve).with("in_test")
      .and_return(double("Stripe::Invoice", hosted_invoice_url: "https://invoice.stripe.com/i/acct_test/test"))
    order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123")

    post_signed_event("checkout.session.completed", { id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test", invoice: "in_test", payment_status: "paid" })

    expect(response).to have_http_status(:ok)
    expect(order.reload.status).to eq("pending")
  end

  it "rejects a request with an invalid signature" do
    payload = { id: "evt_test", type: "checkout.session.completed", data: { object: { id: "cs_test_123" } } }.to_json

    post "/stripe/webhooks",
      params: payload,
      headers: { "Content-Type" => "application/json", "Stripe-Signature" => "t=#{Time.now.to_i},v1=not_a_real_signature" }

    expect(response).to have_http_status(:bad_request)
  end

  it "rejects a request with no signature header at all" do
    post "/stripe/webhooks", params: { id: "evt_test" }.to_json, headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
  end
end
