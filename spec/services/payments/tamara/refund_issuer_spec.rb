require "rails_helper"

RSpec.describe Payments::Tamara::RefundIssuer do
  def stub_tamara_refund
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      instance_double(Net::HTTPResponse, body: "{}", is_a?: true, code: "200")
    end
    http
  end

  it "issues a full refund via the simplified-refund endpoint, keyed by tamara_order_id" do
    sent_path = nil
    sent_body = nil
    http = stub_tamara_refund
    allow(http).to receive(:request) do |req|
      sent_path = req.path
      sent_body = JSON.parse(req.body)
      instance_double(Net::HTTPResponse, body: "{}", is_a?: true, code: "200")
    end
    order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_123", total_cents: 10_000)

    described_class.call(order: order)

    expect(sent_path).to eq("/payments/simplified-refund/order_123")
    expect(sent_body).to eq(
      "total_amount" => { "amount" => 100.0, "currency" => "AED" },
      "comment" => "Refund for Zoomora order #{order.order_number}",
      "merchant_refund_id" => "#{order.order_number}-refund"
    )
    order.reload
    expect(order.status).to eq("refunded")
    expect(order.refunded_cents).to eq(10_000)
    expect(order.refunded_at).to be_present
  end

  it "restores stock when the refunded order hasn't shipped yet" do
    stub_tamara_refund
    product = create(:product, stock_quantity: 2, stock_status: "in_stock")
    order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_123", total_cents: 10_000)
    create(:line_item, order: order, product: product, quantity: 1)
    product.decrement!(:stock_quantity, 1)
    product.sync_stock_status!

    described_class.call(order: order)

    expect(product.reload.stock_quantity).to eq(2)
  end

  it "does not restore stock when the refunded order already shipped" do
    stub_tamara_refund
    product = create(:product, stock_quantity: 1, stock_status: "in_stock")
    order = create(:order, payment_method: "tamara", status: "shipped", tamara_order_id: "order_123", total_cents: 10_000)
    create(:line_item, order: order, product: product, quantity: 1)

    described_class.call(order: order)

    expect(product.reload.stock_quantity).to eq(1)
  end

  it "sends the confirmation-of-refund email exactly once" do
    stub_tamara_refund
    order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_123", total_cents: 10_000)

    expect { described_class.call(order: order) }.to have_enqueued_mail(OrderMailer, :refunded)
  end

  it "does not double-refund (or double-restore stock, or double-send the email) if a concurrent order_refunded webhook already processed this exact refund" do
    stub_tamara_refund
    product = create(:product, stock_quantity: 2, stock_status: "in_stock")
    order = create(:order, payment_method: "tamara", status: "processing", tamara_order_id: "order_123", total_cents: 10_000,
      refunded_cents: 10_000, refunded_at: 1.minute.ago) # webhook already won the race
    create(:line_item, order: order, product: product, quantity: 1)
    order.update_column(:status, "refunded")

    expect { described_class.call(order: order) }.not_to have_enqueued_mail(OrderMailer, :refunded)
    expect(product.reload.stock_quantity).to eq(2) # unchanged — webhook's own restore already ran (or didn't apply)
  end
end
