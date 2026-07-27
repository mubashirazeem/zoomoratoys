require "rails_helper"

RSpec.describe Payments::ResumeCardOrder do
  let(:user) { create(:user) }
  let(:product) { create(:product, price_cents: 10_000, stock_quantity: 5) }
  let(:order) do
    create(:order, user: user, payment_method: "card", status: "awaiting_payment", total_cents: 10_000, subtotal_cents: 10_000).tap do |o|
      create(:line_item, order: o, product: product, quantity: 1, price_cents: 10_000)
    end
  end
  let(:args) do
    {
      user: user,
      success_url_for: ->(o) { "https://example.com/checkout/confirmation/#{o.order_number}" },
      cancel_url: "https://example.com/account/orders/#{order.id}"
    }
  end

  it "creates a fresh Stripe Checkout Session when the order has none yet",
     vcr: { cassette_name: "payments/resume_card_order/creates_fresh_session" } do
    url = Payments::ResumeCardOrder.call(order: order, **args)

    expect(url).to start_with("https://checkout.stripe.com/")
    expect(order.reload.stripe_checkout_session_id).to be_present
  end

  it "reuses the existing session if it's still open, without creating a second one",
     vcr: { cassette_name: "payments/resume_card_order/reuses_open_session" } do
    first_url = Payments::ResumeCardOrder.call(order: order, **args)
    tracked_session_id = order.reload.stripe_checkout_session_id

    second_url = Payments::ResumeCardOrder.call(order: order, **args)

    expect(second_url).to eq(first_url)
    expect(order.reload.stripe_checkout_session_id).to eq(tracked_session_id)
  end

  it "creates a new session when the tracked session id no longer exists in Stripe",
     vcr: { cassette_name: "payments/resume_card_order/stale_session_id" } do
    order.update!(stripe_checkout_session_id: "cs_test_nonexistent_stale_id")

    url = Payments::ResumeCardOrder.call(order: order, **args)

    expect(url).to start_with("https://checkout.stripe.com/")
    expect(order.reload.stripe_checkout_session_id).not_to eq("cs_test_nonexistent_stale_id")
  end

  it "charges through the order's own already-fixed coupon discount, not a re-evaluated one",
     vcr: { cassette_name: "payments/resume_card_order/keeps_original_discount" } do
    coupon = create(:coupon, code: "RESUME20", discount_type: "percentage", discount_value: 20)
    Payments::CouponSync.create(coupon)
    order.update!(coupon: coupon, discount_cents: 2_000, total_cents: 8_000)

    sent_params = nil
    allow(Stripe::Checkout::Session).to receive(:create).and_wrap_original do |original, params|
      sent_params = params
      original.call(params)
    end

    Payments::ResumeCardOrder.call(order: order, **args)

    expect(sent_params[:discounts]).to eq([ { promotion_code: coupon.stripe_promotion_code_id } ])
  end
end
