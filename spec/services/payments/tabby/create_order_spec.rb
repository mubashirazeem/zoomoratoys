require "rails_helper"

RSpec.describe Payments::Tabby::CreateOrder, type: :model do
  def stub_tabby_response(status, body)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    response = instance_double(Net::HTTPResponse, body: body.to_json, is_a?: status == 200, code: status.to_s)
    allow(http).to receive(:request).and_return(response)
  end

  let(:user) { create(:user) }
  let(:product) { create(:product, price_cents: 10_000, stock_quantity: 5) }
  let(:cart) { create(:cart, user: user) }

  before { create(:cart_item, cart: cart, product: product, quantity: 1) }

  it "creates an awaiting_payment order and returns the real web_url from Tabby" do
    stub_tabby_response(200, {
      "payment" => { "id" => "pay_123" },
      "configuration" => { "available_products" => { "installments" => [ { "web_url" => "https://checkout.tabby.ai/pay_123" } ] } }
    })

    url = described_class.call(
      cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
        shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
      success_url_for: ->(order) { "https://example.com/success/#{order.order_number}" },
      cancel_url: "https://example.com/cancel", failure_url: "https://example.com/failure"
    )

    expect(url).to eq("https://checkout.tabby.ai/pay_123")
    order = Order.find_by(user: user)
    expect(order.payment_method).to eq("tabby")
    expect(order.status).to eq("awaiting_payment")
    expect(order.tabby_payment_id).to eq("pay_123")
    expect(order.total_cents).to eq(10_000)
  end

  it "does not create an order, and stock is not reserved, when Tabby's response is missing a web_url" do
    stub_tabby_response(200, { "payment" => { "id" => "pay_123" }, "configuration" => {} })

    expect {
      expect {
        described_class.call(
          cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
            shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
          success_url_for: ->(order) { "x" }, cancel_url: "x", failure_url: "x"
        )
      }.to raise_error(Payments::ProviderError)
    }.not_to change(Order, :count)

    expect(product.reload.stock_quantity).to eq(5)
  end

  it "rolls the order back entirely when Tabby's API returns an error — the stock reservation must not survive a failed session" do
    stub_tabby_response(422, { "error" => "invalid_request" })

    expect {
      expect {
        described_class.call(
          cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
            shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
          success_url_for: ->(order) { "x" }, cancel_url: "x", failure_url: "x"
        )
      }.to raise_error(Payments::ProviderError)
    }.not_to change(Order, :count)

    expect(product.reload.stock_quantity).to eq(5)
  end

  it "sends the returning customer's real past orders as order_history, excluding awaiting_payment and the new order itself" do
    old_order = create(:order, user: user, status: "delivered", placed_at: 2.days.ago,
      shipping_name: "Layla", shipping_phone: "+971500000000", shipping_city: "Dubai",
      shipping_address_line1: "Villa 1", total_cents: 5_000)
    create(:order, user: user, status: "awaiting_payment", placed_at: 1.day.ago) # must be excluded

    sent_body = nil
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      sent_body = JSON.parse(req.body)
      instance_double(Net::HTTPResponse, body: {
        "payment" => { "id" => "pay_123" },
        "configuration" => { "available_products" => { "installments" => [ { "web_url" => "https://checkout.tabby.ai/pay_123" } ] } }
      }.to_json, is_a?: true, code: "200")
    end

    described_class.call(
      cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
        shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
      success_url_for: ->(order) { "x" }, cancel_url: "x", failure_url: "x"
    )

    history = sent_body["payment"]["order_history"]
    expect(history.size).to eq(1)
    expect(history.first["status"]).to eq("complete")
    expect(history.first["amount"]).to eq("50.00")
    expect(history.first["purchased_at"]).to eq(old_order.placed_at.iso8601)
    expect(history.first["buyer"]["name"]).to eq("Layla")
    # loyalty_level: real count of successfully placed past orders — the
    # awaiting_payment one above must not count.
    expect(sent_body["payment"]["buyer_history"]["loyalty_level"]).to eq(1)
  end

  it "never reports order_history status as \"new\" for an already-paid order, and excludes cancelled orders from loyalty_level — both real gaps Tabby's own QA caught" do
    create(:order, user: user, status: "pending", placed_at: 1.day.ago, total_cents: 5_000) # paid, not yet processing
    create(:order, user: user, status: "cancelled", placed_at: 2.days.ago) # never a completed purchase

    sent_body = nil
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      sent_body = JSON.parse(req.body)
      instance_double(Net::HTTPResponse, body: {
        "payment" => { "id" => "pay_123" },
        "configuration" => { "available_products" => { "installments" => [ { "web_url" => "https://checkout.tabby.ai/pay_123" } ] } }
      }.to_json, is_a?: true, code: "200")
    end

    described_class.call(
      cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
        shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
      success_url_for: ->(order) { "x" }, cancel_url: "x", failure_url: "x"
    )

    history = sent_body["payment"]["order_history"]
    expect(history.map { |h| h["status"] }).to eq([ "processing", "canceled" ])
    expect(sent_body["payment"]["buyer_history"]["loyalty_level"]).to eq(1) # the pending one only, not the cancelled one
  end

  it "raises SessionRejected (not ProviderError) on a rejected session, creating nothing and leaving the cart intact" do
    stub_tabby_response(200, {
      "status" => "rejected",
      "configuration" => { "products" => { "installments" => { "is_available" => false, "rejection_reason" => "not_available" } } }
    })

    expect {
      expect {
        described_class.call(
          cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
            shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
          success_url_for: ->(order) { "x" }, cancel_url: "https://example.com/cancel", failure_url: "https://example.com/failure"
        )
      }.to raise_error(Payments::SessionRejected, "Tabby isn't available for this order right now.")
    }.not_to change(Order, :count)

    expect(product.reload.stock_quantity).to eq(5)
    expect(cart.cart_items.count).to eq(1)
  end

  it "tags the cancel/failure URLs with this order's number so a bounce-back can be identified" do
    sent_body = nil
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      sent_body = JSON.parse(req.body)
      instance_double(Net::HTTPResponse, body: {
        "payment" => { "id" => "pay_123" },
        "configuration" => { "available_products" => { "installments" => [ { "web_url" => "https://checkout.tabby.ai/pay_123" } ] } }
      }.to_json, is_a?: true, code: "200")
    end

    described_class.call(
      cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
        shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
      success_url_for: ->(order) { "x" }, cancel_url: "https://example.com/checkout", failure_url: "https://example.com/checkout"
    )

    order = Order.find_by(user: user)
    expect(sent_body["merchant_urls"]["cancel"]).to eq("https://example.com/checkout?tabby_recover=#{order.order_number}")
    expect(sent_body["merchant_urls"]["failure"]).to eq("https://example.com/checkout?tabby_recover=#{order.order_number}")
  end

  it "rolls the order back entirely when Tabby is unreachable — a network failure, not an HTTP error response, must be treated the same way" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

    expect {
      expect {
        described_class.call(
          cart: cart, user: user, shipping_attributes: { shipping_name: "Layla", shipping_phone: "+971500000000",
            shipping_address_line1: "Villa 1", shipping_city: "Dubai", shipping_emirate: "Dubai" },
          success_url_for: ->(order) { "x" }, cancel_url: "x", failure_url: "x"
        )
      }.to raise_error(Payments::ProviderError)
    }.not_to change(Order, :count)

    expect(product.reload.stock_quantity).to eq(5)
  end
end
