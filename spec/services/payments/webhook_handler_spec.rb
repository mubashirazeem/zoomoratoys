require "rails_helper"

RSpec.describe Payments::WebhookHandler do
  # Builds a real Stripe::Event via the exact same Stripe::Webhook
  # .construct_event the real controller uses (Task 5's
  # StripeWebhooksController) — genuine HMAC signing and verification, not
  # a hand-built double standing in for Stripe's own object shape.
  def stripe_event(type, object_attrs)
    payload = { id: "evt_test", type: type, data: { object: object_attrs } }.to_json
    timestamp = Time.now.to_i
    signature = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("STRIPE_WEBHOOK_SECRET"), "#{timestamp}.#{payload}")

    Stripe::Webhook.construct_event(payload, "t=#{timestamp},v1=#{signature}", ENV.fetch("STRIPE_WEBHOOK_SECRET"))
  end

  describe "checkout.session.completed" do
    it "moves an awaiting_payment order to pending and records the payment reference" do
      allow(Stripe::Invoice).to receive(:retrieve).with("in_test_789")
        .and_return(double("Stripe::Invoice", hosted_invoice_url: "https://invoice.stripe.com/i/acct_test/test_789"))
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123")
      event = stripe_event("checkout.session.completed", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test_456", invoice: "in_test_789", payment_status: "paid"
      })

      Payments::WebhookHandler.call(event)

      order.reload
      expect(order.status).to eq("pending")
      expect(order.stripe_payment_intent_id).to eq("pi_test_456")
      expect(order.stripe_invoice_id).to eq("in_test_789")
    end

    it "increments the coupon's times_used once payment is confirmed — matching Stripe's own promotion-code redemption timing, not order creation" do
      allow(Stripe::Invoice).to receive(:retrieve).and_return(double("Stripe::Invoice", hosted_invoice_url: nil))
      coupon = create(:coupon, times_used: 0)
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123", coupon: coupon)
      event = stripe_event("checkout.session.completed", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test_456", invoice: "in_test_789", payment_status: "paid"
      })

      Payments::WebhookHandler.call(event)

      expect(coupon.reload.times_used).to eq(1)
    end

    it "does not touch times_used for an order with no coupon" do
      allow(Stripe::Invoice).to receive(:retrieve).and_return(double("Stripe::Invoice", hosted_invoice_url: nil))
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123", coupon: nil)
      event = stripe_event("checkout.session.completed", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test_456", invoice: "in_test_789", payment_status: "paid"
      })

      expect { Payments::WebhookHandler.call(event) }.not_to raise_error
      expect(order.reload.status).to eq("pending")
    end

    it "does not double-increment times_used on a redelivered event" do
      allow(Stripe::Invoice).to receive(:retrieve).and_return(double("Stripe::Invoice", hosted_invoice_url: nil))
      coupon = create(:coupon, times_used: 0)
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123", coupon: coupon)
      event = stripe_event("checkout.session.completed", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test_456", invoice: "in_test_789", payment_status: "paid"
      })

      Payments::WebhookHandler.call(event)
      Payments::WebhookHandler.call(event)

      expect(coupon.reload.times_used).to eq(1)
    end

    it "fetches and stores the customer-facing hosted invoice URL — the real, no-login-required receipt link Stripe shows on the invoice, not just the internal invoice id" do
      allow(Stripe::Invoice).to receive(:retrieve).with("in_test_789")
        .and_return(double("Stripe::Invoice", hosted_invoice_url: "https://invoice.stripe.com/i/acct_test/test_789"))
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123")
      event = stripe_event("checkout.session.completed", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test_456", invoice: "in_test_789", payment_status: "paid"
      })

      Payments::WebhookHandler.call(event)

      expect(order.reload.stripe_hosted_invoice_url).to eq("https://invoice.stripe.com/i/acct_test/test_789")
    end

    it "still confirms the order even if fetching the hosted invoice URL fails — that's a supplementary convenience, not the critical payment confirmation" do
      allow(Stripe::Invoice).to receive(:retrieve).with("in_test_789").and_raise(Stripe::APIConnectionError.new("simulated"))
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123")
      event = stripe_event("checkout.session.completed", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test_456", invoice: "in_test_789", payment_status: "paid"
      })

      Payments::WebhookHandler.call(event)

      order.reload
      expect(order.status).to eq("pending")
      expect(order.stripe_payment_intent_id).to eq("pi_test_456")
      expect(order.stripe_hosted_invoice_url).to be_nil
    end

    it "is idempotent — a redelivered event for an already-confirmed order is a no-op" do
      allow(Stripe::Invoice).to receive(:retrieve)
      order = create(:order, status: "processing", payment_method: "card", stripe_checkout_session_id: "cs_test_123",
                              stripe_payment_intent_id: "pi_original")
      event = stripe_event("checkout.session.completed", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_different", invoice: "in_different", payment_status: "paid"
      })

      Payments::WebhookHandler.call(event)

      expect(order.reload.status).to eq("processing")
      expect(order.stripe_payment_intent_id).to eq("pi_original")
      expect(Stripe::Invoice).not_to have_received(:retrieve)
    end

    it "does not raise when no matching order exists" do
      event = stripe_event("checkout.session.completed", { id: "cs_test_unknown", object: "checkout.session", payment_intent: "pi_x", invoice: "in_x", payment_status: "paid" })

      expect { Payments::WebhookHandler.call(event) }.not_to raise_error
    end

    it "does not confirm the order when payment_status is unpaid — Stripe fires this event for delayed/async payment methods before the payment actually clears, not only once it has" do
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123")
      event = stripe_event("checkout.session.completed", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test_456", invoice: "in_test_789", payment_status: "unpaid"
      })

      Payments::WebhookHandler.call(event)

      expect(order.reload.status).to eq("awaiting_payment")
    end
  end

  describe "checkout.session.async_payment_succeeded" do
    it "confirms the order — fires once a delayed payment method that was still unpaid at checkout.session.completed actually clears" do
      allow(Stripe::Invoice).to receive(:retrieve)
        .and_return(double("Stripe::Invoice", hosted_invoice_url: "https://invoice.stripe.com/i/acct_test/test_789"))
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123")
      event = stripe_event("checkout.session.async_payment_succeeded", {
        id: "cs_test_123", object: "checkout.session", payment_intent: "pi_test_456", invoice: "in_test_789", payment_status: "paid"
      })

      Payments::WebhookHandler.call(event)

      order.reload
      expect(order.status).to eq("pending")
      expect(order.stripe_payment_intent_id).to eq("pi_test_456")
    end
  end

  describe "checkout.session.async_payment_failed" do
    it "cancels the order and restores reserved stock — the delayed payment method ultimately failed" do
      product = create(:product, stock_quantity: 3)
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123")
      create(:line_item, order: order, product: product, quantity: 2)
      event = stripe_event("checkout.session.async_payment_failed", { id: "cs_test_123", object: "checkout.session" })

      Payments::WebhookHandler.call(event)

      expect(order.reload.status).to eq("cancelled")
      expect(product.reload.stock_quantity).to eq(5)
    end
  end

  describe "checkout.session.expired" do
    it "cancels the order and restores reserved stock" do
      product = create(:product, stock_quantity: 3)
      order = create(:order, status: "awaiting_payment", payment_method: "card", stripe_checkout_session_id: "cs_test_123")
      create(:line_item, order: order, product: product, quantity: 2)
      event = stripe_event("checkout.session.expired", { id: "cs_test_123", object: "checkout.session" })

      Payments::WebhookHandler.call(event)

      expect(order.reload.status).to eq("cancelled")
      expect(product.reload.stock_quantity).to eq(5)
    end

    it "does nothing if the order already moved past awaiting_payment" do
      order = create(:order, status: "pending", payment_method: "card", stripe_checkout_session_id: "cs_test_123")
      event = stripe_event("checkout.session.expired", { id: "cs_test_123", object: "checkout.session" })

      Payments::WebhookHandler.call(event)

      expect(order.reload.status).to eq("pending")
    end
  end

  describe "charge.refunded" do
    it "marks the order refunded, syncing a full refund issued directly from the Stripe dashboard" do
      order = create(:order, status: "processing", payment_method: "card", stripe_payment_intent_id: "pi_test_456", total_cents: 21_500)
      event = stripe_event("charge.refunded", { id: "ch_test", object: "charge", payment_intent: "pi_test_456", amount_refunded: 21_500, refunded: true })

      Payments::WebhookHandler.call(event)

      order.reload
      expect(order.status).to eq("refunded")
      expect(order.refunded_cents).to eq(21_500)
      expect(order.refunded_at).to be_present
    end

    it "restores stock when the order hasn't shipped yet" do
      product = create(:product, stock_quantity: 2, stock_status: "in_stock")
      order = create(:order, status: "processing", payment_method: "card", stripe_payment_intent_id: "pi_test_456", total_cents: 10_000)
      create(:line_item, order: order, product: product, quantity: 1)
      product.decrement!(:stock_quantity, 1)
      product.sync_stock_status!
      event = stripe_event("charge.refunded", { id: "ch_test", object: "charge", payment_intent: "pi_test_456", amount_refunded: 10_000, refunded: true })

      Payments::WebhookHandler.call(event)

      expect(product.reload.stock_quantity).to eq(2)
    end

    it "does not restore stock when the order already shipped" do
      product = create(:product, stock_quantity: 1, stock_status: "in_stock")
      order = create(:order, status: "shipped", payment_method: "card", stripe_payment_intent_id: "pi_test_456", total_cents: 10_000)
      create(:line_item, order: order, product: product, quantity: 1)
      event = stripe_event("charge.refunded", { id: "ch_test", object: "charge", payment_intent: "pi_test_456", amount_refunded: 10_000, refunded: true })

      Payments::WebhookHandler.call(event)

      expect(product.reload.stock_quantity).to eq(1)
    end

    it "is idempotent — a redelivered event for an already-refunded order does not double-restore stock" do
      product = create(:product, stock_quantity: 2, stock_status: "in_stock")
      order = create(:order, status: "processing", payment_method: "card", stripe_payment_intent_id: "pi_test_456", total_cents: 10_000)
      create(:line_item, order: order, product: product, quantity: 1)
      product.decrement!(:stock_quantity, 1)
      product.sync_stock_status!
      event = stripe_event("charge.refunded", { id: "ch_test", object: "charge", payment_intent: "pi_test_456", amount_refunded: 10_000, refunded: true })

      Payments::WebhookHandler.call(event) # first delivery: restores stock, 1 -> 2
      Payments::WebhookHandler.call(event) # redelivery: must not restore again

      expect(product.reload.stock_quantity).to eq(2)
    end

    it "does NOT mark the order refunded or restore stock for a partial refund — e.g. a goodwill AED 50 refund on a AED 200 order issued from the Stripe dashboard" do
      product = create(:product, stock_quantity: 2, stock_status: "in_stock")
      order = create(:order, status: "processing", payment_method: "card", stripe_payment_intent_id: "pi_test_456", total_cents: 20_000)
      create(:line_item, order: order, product: product, quantity: 1)
      product.decrement!(:stock_quantity, 1)
      product.sync_stock_status!
      event = stripe_event("charge.refunded", { id: "ch_test", object: "charge", payment_intent: "pi_test_456", amount_refunded: 5_000, refunded: false })

      Payments::WebhookHandler.call(event)

      order.reload
      expect(order.status).to eq("processing")
      expect(order.refunded_cents).to eq(5_000)
      expect(order.refunded_at).to be_nil
      expect(product.reload.stock_quantity).to eq(1)
    end

    it "records the cumulative amount across two partial refunds, and only marks it fully refunded once the second one covers the rest" do
      order = create(:order, status: "processing", payment_method: "card", stripe_payment_intent_id: "pi_test_456", total_cents: 20_000)
      first_event = stripe_event("charge.refunded", { id: "ch_test", object: "charge", payment_intent: "pi_test_456", amount_refunded: 5_000, refunded: false })
      second_event = stripe_event("charge.refunded", { id: "ch_test", object: "charge", payment_intent: "pi_test_456", amount_refunded: 20_000, refunded: true })

      Payments::WebhookHandler.call(first_event)
      expect(order.reload.status).to eq("processing")
      expect(order.refunded_cents).to eq(5_000)

      Payments::WebhookHandler.call(second_event)
      expect(order.reload.status).to eq("refunded")
      expect(order.refunded_cents).to eq(20_000)
    end
  end

  describe "charge.dispute.created" do
    it "records the dispute status on the order so it's visible without checking Stripe directly" do
      order = create(:order, status: "processing", payment_method: "card", stripe_payment_intent_id: "pi_test_456")
      event = stripe_event("charge.dispute.created", { id: "dp_test", object: "dispute", payment_intent: "pi_test_456", status: "needs_response" })

      Payments::WebhookHandler.call(event)

      expect(order.reload.stripe_dispute_status).to eq("needs_response")
    end

    it "does not raise when no matching order exists" do
      event = stripe_event("charge.dispute.created", { id: "dp_test", object: "dispute", payment_intent: "pi_unknown", status: "needs_response" })

      expect { Payments::WebhookHandler.call(event) }.not_to raise_error
    end
  end

  describe "charge.dispute.closed" do
    it "updates the dispute status to its final outcome" do
      order = create(:order, status: "processing", payment_method: "card", stripe_payment_intent_id: "pi_test_456", stripe_dispute_status: "needs_response")
      event = stripe_event("charge.dispute.closed", { id: "dp_test", object: "dispute", payment_intent: "pi_test_456", status: "won" })

      Payments::WebhookHandler.call(event)

      expect(order.reload.stripe_dispute_status).to eq("won")
    end
  end
end
