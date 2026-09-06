require "rails_helper"

RSpec.describe Payments::Tamara::CreateOrder, type: :model do
  def stub_tamara_response(status, body)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    response = instance_double(Net::HTTPResponse, body: body.to_json, is_a?: status == 200, code: status.to_s)
    allow(http).to receive(:request).and_return(response)
  end

  let(:user) { create(:user) }
  let(:product) { create(:product, price_cents: 10_000, stock_quantity: 5) }
  let(:cart) { create(:cart, user: user) }

  before { create(:cart_item, cart: cart, product: product, quantity: 1) }

  def call_it
    described_class.call(
      cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
        shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
      success_url_for: ->(order) { "https://example.com/success/#{order.order_number}" },
      cancel_url: "https://example.com/cancel", failure_url: "https://example.com/failure",
      notification_url: "https://example.com/tamara/webhooks"
    )
  end

  it "creates an awaiting_payment order and returns the real checkout_url from Tamara" do
    stub_tamara_response(200, { "order_id" => "order_abc", "checkout_id" => "chk_1", "checkout_url" => "https://checkout.tamara.co/chk_1", "status" => "new" })

    url = call_it

    expect(url).to eq("https://checkout.tamara.co/chk_1")
    order = Order.find_by(user: user)
    expect(order.payment_method).to eq("tamara")
    expect(order.status).to eq("awaiting_payment")
    expect(order.tamara_order_id).to eq("order_abc")
    expect(order.total_cents).to eq(10_000)
  end

  it "does not create an order when Tamara's response is missing a checkout_url" do
    stub_tamara_response(200, { "order_id" => "order_abc" })

    expect {
      expect { call_it }.to raise_error(Payments::ProviderError)
    }.not_to change(Order, :count)

    expect(product.reload.stock_quantity).to eq(5)
  end

  it "rolls the order back entirely when Tamara's API returns an error" do
    stub_tamara_response(400, { "message" => "invalid request" })

    expect {
      expect { call_it }.to raise_error(Payments::ProviderError)
    }.not_to change(Order, :count)

    expect(product.reload.stock_quantity).to eq(5)
  end

  it "sends shipping_amount and tax_amount — Tamara's own required fields, missing here for months, is what actually caused the real \"Something went wrong with us\" 500s (confirmed empirically: omitting only one gets a clean validation error, omitting both crashes their backend into that generic message)" do
    sent_body = nil
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      sent_body = JSON.parse(req.body)
      instance_double(Net::HTTPResponse,
        body: { "order_id" => "order_abc", "checkout_id" => "chk_1", "checkout_url" => "https://checkout.tamara.co/chk_1", "status" => "new" }.to_json,
        is_a?: true, code: "200")
    end

    call_it

    expect(sent_body["shipping_amount"]).to eq({ "amount" => "0.00", "currency" => "AED" })
    # 5% VAT already included in the AED 100 subtotal — Order#vat_cents is
    # the same figure shown to the customer as "Includes VAT (5%): ...".
    expect(sent_body["tax_amount"]).to eq({ "amount" => "4.76", "currency" => "AED" })
  end

  it "rolls the order back entirely when Tamara is unreachable — a network failure, not an HTTP error response, must be treated the same way" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

    expect {
      expect { call_it }.to raise_error(Payments::ProviderError)
    }.not_to change(Order, :count)

    expect(product.reload.stock_quantity).to eq(5)
  end
end
