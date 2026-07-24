require "rails_helper"

RSpec.describe Payments::RefundIssuer do
  it "issues a real full refund and marks the order refunded",
     vcr: { cassette_name: "payments/refund_issuer/full_refund" } do
    # A real, confirmed test-mode PaymentIntent — created here (and recorded
    # into the same cassette as the refund below) so the refund itself is
    # issued against a payment_intent id that genuinely exists in Stripe's
    # test-mode account, the same as it would in production.
    payment_intent = Stripe::PaymentIntent.create(
      amount: 10_000, currency: "aed", payment_method: "pm_card_visa",
      confirm: true, automatic_payment_methods: { enabled: true, allow_redirects: "never" }
    )
    order = create(:order, payment_method: "card", status: "processing",
                            stripe_payment_intent_id: payment_intent.id, total_cents: 10_000)

    Payments::RefundIssuer.call(order: order)

    order.reload
    expect(order.status).to eq("refunded")
    expect(order.refunded_cents).to eq(10_000)
    expect(order.refunded_at).to be_present
  end

  it "restores stock when the refunded order hasn't shipped yet",
     vcr: { cassette_name: "payments/refund_issuer/restores_stock_not_shipped" } do
    payment_intent = Stripe::PaymentIntent.create(
      amount: 10_000, currency: "aed", payment_method: "pm_card_visa",
      confirm: true, automatic_payment_methods: { enabled: true, allow_redirects: "never" }
    )
    product = create(:product, stock_quantity: 2, stock_status: "in_stock")
    order = create(:order, payment_method: "card", status: "processing",
                            stripe_payment_intent_id: payment_intent.id, total_cents: 10_000)
    create(:line_item, order: order, product: product, quantity: 1)
    product.decrement!(:stock_quantity, 1)
    product.sync_stock_status!

    Payments::RefundIssuer.call(order: order)

    expect(product.reload.stock_quantity).to eq(2)
  end

  it "does not restore stock when the refunded order already shipped",
     vcr: { cassette_name: "payments/refund_issuer/no_restore_when_shipped" } do
    payment_intent = Stripe::PaymentIntent.create(
      amount: 10_000, currency: "aed", payment_method: "pm_card_visa",
      confirm: true, automatic_payment_methods: { enabled: true, allow_redirects: "never" }
    )
    product = create(:product, stock_quantity: 1, stock_status: "in_stock")
    order = create(:order, payment_method: "card", status: "shipped",
                            stripe_payment_intent_id: payment_intent.id, total_cents: 10_000)
    create(:line_item, order: order, product: product, quantity: 1)

    Payments::RefundIssuer.call(order: order)

    expect(product.reload.stock_quantity).to eq(1)
  end
end
