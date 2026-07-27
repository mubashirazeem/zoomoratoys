require "rails_helper"

RSpec.describe Payments::CreateCardOrder do
  let(:user) { create(:user) }
  let(:shipping_attributes) do
    {
      shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
      shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai",
      shipping_emirate: "Dubai"
    }
  end

  it "creates an awaiting_payment order, reserves stock, and returns a real Stripe-hosted checkout URL",
     vcr: { cassette_name: "payments/create_card_order/basic_session" } do
    product = create(:product, price_cents: 10_000, stock_quantity: 5)
    cart = create(:cart, user: user)
    create(:cart_item, cart: cart, product: product, quantity: 2)

    url = Payments::CreateCardOrder.call(
      cart: cart, user: user, shipping_attributes: shipping_attributes,
      success_url_for: ->(order) { "https://example.com/checkout/confirmation/#{order.order_number}" },
      cancel_url: "https://example.com/checkout"
    )

    order = Order.last
    expect(order.payment_method).to eq("card")
    expect(order.status).to eq("awaiting_payment")
    expect(order.stripe_checkout_session_id).to be_present
    expect(product.reload.stock_quantity).to eq(3)
    expect(url).to start_with("https://checkout.stripe.com/")
  end

  it "records the actually-discounted total on the order, matching what Stripe will charge",
     vcr: { cassette_name: "payments/create_card_order/coupon_discount_matches_order_total" } do
    coupon = create(:coupon, code: "TESTDISCOUNT20", discount_type: "percentage", discount_value: 20)
    Payments::CouponSync.create(coupon)
    product = create(:product, price_cents: 10_000, stock_quantity: 5)
    cart = create(:cart, user: user, coupon: coupon)
    create(:cart_item, cart: cart, product: product, quantity: 2)

    Payments::CreateCardOrder.call(
      cart: cart, user: user, shipping_attributes: shipping_attributes,
      success_url_for: ->(order) { "https://example.com/checkout/confirmation/#{order.order_number}" },
      cancel_url: "https://example.com/checkout"
    )

    order = Order.last
    expect(order.discount_cents).to eq(4_000)
    expect(order.total_cents).to eq(16_000)
    expect(order.coupon).to eq(coupon)
  end

  it "leaves coupon nil when the cart has none applied" do
    product = create(:product, price_cents: 10_000, stock_quantity: 5)
    cart = create(:cart, user: user)
    create(:cart_item, cart: cart, product: product, quantity: 1)

    VCR.use_cassette("payments/create_card_order/basic_session") do
      Payments::CreateCardOrder.call(
        cart: cart, user: user, shipping_attributes: shipping_attributes,
        success_url_for: ->(order) { "https://example.com/checkout/confirmation/#{order.order_number}" },
        cancel_url: "https://example.com/checkout"
      )
    end

    expect(Order.last.coupon).to be_nil
  end

  it "puts order metadata on the PaymentIntent, not just the Checkout Session",
     vcr: { cassette_name: "payments/create_card_order/payment_intent_metadata" } do
    # Stripe does not propagate metadata between objects: metadata set at
    # the top level of a Checkout Session only lives on the Session itself,
    # not on the PaymentIntent it creates — confirmed against a real
    # completed test-mode payment, whose "Metadata" panel showed nothing
    # despite the Session-level metadata being set correctly. Fixed via the
    # separate payment_intent_data.metadata param, which Stripe copies onto
    # the PaymentIntent (and from there, the Charge) — so anyone looking at
    # the raw payment in the Stripe dashboard, not just the Checkout
    # Session, can see which order it belongs to.
    #
    # This spies on the real call's arguments (via and_call_original — the
    # actual Stripe API is still hit for real and VCR still records it)
    # rather than reading the cassette file, since VCR only flushes that
    # file to disk once the example finishes, not while it's still running.
    product = create(:product, price_cents: 10_000, stock_quantity: 5)
    cart = create(:cart, user: user)
    create(:cart_item, cart: cart, product: product, quantity: 1)
    sent_params = nil
    allow(Stripe::Checkout::Session).to receive(:create).and_wrap_original do |original, params|
      sent_params = params
      original.call(params)
    end

    Payments::CreateCardOrder.call(
      cart: cart, user: user, shipping_attributes: shipping_attributes,
      success_url_for: ->(order) { "https://example.com/checkout/confirmation/#{order.order_number}" },
      cancel_url: "https://example.com/checkout"
    )

    order = Order.last
     expect(sent_params[:payment_intent_data]).to eq(
      metadata: { order_id: order.id, order_number: order.order_number, products: "#{product.name} x1" }
    )
  end

  it "creates a real Stripe Customer and reuses it on a second order for the same user",
     vcr: { cassette_name: "payments/create_card_order/reuses_customer" } do
    product = create(:product, price_cents: 10_000, stock_quantity: 10)
    cart = create(:cart, user: user)
    create(:cart_item, cart: cart, product: product, quantity: 1)
    args = {
      user: user, shipping_attributes: shipping_attributes,
      success_url_for: ->(order) { "https://example.com/checkout/confirmation/#{order.order_number}" },
      cancel_url: "https://example.com/checkout"
    }

    Payments::CreateCardOrder.call(cart: cart, **args)
    first_customer_id = user.reload.stripe_customer_id
    expect(first_customer_id).to be_present

    # Reuse the same cart row for the user's second checkout rather than
    # creating a brand-new Cart — Order.create_from_cart! only empties a
    # cart's line items (cart.cart_items.destroy_all), it never deletes the
    # cart itself, and carts.user_id is uniquely indexed (User has_one
    # :cart), so a user never actually has two Cart rows at once. #reload
    # clears the now-stale, already-loaded (and now empty) cart_items
    # association cache left over from the first call.
    cart.reload
    create(:cart_item, cart: cart, product: product, quantity: 1)
    Payments::CreateCardOrder.call(cart: cart, **args)

    expect(user.reload.stripe_customer_id).to eq(first_customer_id)
  end

  # This is the one deliberate exception to "no mocking anywhere" in this
  # plan, and it's narrow and justified: Stripe::APIConnectionError (a real
  # network failure) isn't reproducible through VCR — VCR replays
  # *successful* recorded HTTP exchanges; simulating a dropped connection
  # needs to intercept the Ruby method call itself. Every other Stripe
  # interaction in this suite is tested through a real recorded API
  # exchange.
  it "rolls back the order and stock reservation entirely if Stripe fails" do
    # This user already has a stripe_customer_id so Stripe::Customer.create
    # is never called — the only Stripe interaction in this example is the
    # mocked Stripe::Checkout::Session.create below, keeping the mock
    # narrow. Without this, a fresh user with no stripe_customer_id would
    # trigger a real (unmocked) Stripe::Customer.create call, which VCR's
    # WebMock hook blocks outside a cassette with an unrelated error.
    user_with_stripe_customer = create(:user, stripe_customer_id: "cus_test_existing")
    product = create(:product, price_cents: 10_000, stock_quantity: 5)
    cart = create(:cart, user: user_with_stripe_customer)
    create(:cart_item, cart: cart, product: product, quantity: 2)
    allow(Stripe::Checkout::Session).to receive(:create).and_raise(Stripe::APIConnectionError.new("simulated network failure"))

    expect {
      expect {
        Payments::CreateCardOrder.call(
          cart: cart, user: user_with_stripe_customer, shipping_attributes: shipping_attributes,
          success_url_for: ->(order) { "https://example.com/checkout/confirmation/#{order.order_number}" },
          cancel_url: "https://example.com/checkout"
        )
      }.to raise_error(Stripe::APIConnectionError)
    }.not_to change(Order, :count)

    expect(product.reload.stock_quantity).to eq(5)
  end
end
