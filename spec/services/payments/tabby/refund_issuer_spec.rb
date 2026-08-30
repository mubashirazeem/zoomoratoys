require "rails_helper"

RSpec.describe Payments::Tabby::RefundIssuer do
  def stub_tabby_refund
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      instance_double(Net::HTTPResponse, body: "{}", is_a?: true, code: "200")
    end
    http
  end

  it "issues a full refund with its own unique reference_id, distinct from the capture's" do
    sent_body = nil
    http = stub_tabby_refund
    allow(http).to receive(:request) do |req|
      sent_body = JSON.parse(req.body) if req.path.include?("/refunds")
      instance_double(Net::HTTPResponse, body: "{}", is_a?: true, code: "200")
    end
    order = create(:order, payment_method: "tabby", status: "processing", tabby_payment_id: "pay_123", total_cents: 10_000)

    described_class.call(order: order)

    expect(sent_body).to eq("amount" => "100.00", "reference_id" => "#{order.order_number}-refund")
    order.reload
    expect(order.status).to eq("refunded")
    expect(order.refunded_cents).to eq(10_000)
    expect(order.refunded_at).to be_present
  end

  it "restores stock when the refunded order hasn't shipped yet" do
    stub_tabby_refund
    product = create(:product, stock_quantity: 2, stock_status: "in_stock")
    order = create(:order, payment_method: "tabby", status: "processing", tabby_payment_id: "pay_123", total_cents: 10_000)
    create(:line_item, order: order, product: product, quantity: 1)
    product.decrement!(:stock_quantity, 1)
    product.sync_stock_status!

    described_class.call(order: order)

    expect(product.reload.stock_quantity).to eq(2)
  end

  it "does not restore stock when the refunded order already shipped" do
    stub_tabby_refund
    product = create(:product, stock_quantity: 1, stock_status: "in_stock")
    order = create(:order, payment_method: "tabby", status: "shipped", tabby_payment_id: "pay_123", total_cents: 10_000)
    create(:line_item, order: order, product: product, quantity: 1)

    described_class.call(order: order)

    expect(product.reload.stock_quantity).to eq(1)
  end

  it "sends the confirmation-of-refund email exactly once" do
    stub_tabby_refund
    order = create(:order, payment_method: "tabby", status: "processing", tabby_payment_id: "pay_123", total_cents: 10_000)

    expect { described_class.call(order: order) }.to have_enqueued_mail(OrderMailer, :refunded)
  end
end
