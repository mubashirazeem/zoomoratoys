require "rails_helper"

RSpec.describe "Checkouts", type: :request do
  let(:shipping_params) do
    {
      shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
      shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai",
      shipping_emirate: "Dubai"
    }
  end

  describe "GET /checkout" do
    it "requires sign-in" do
      get checkout_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to the cart when there's nothing to check out" do
      sign_in create(:user)

      get checkout_path

      expect(response).to redirect_to(cart_path)
    end

    it "redirects to the cart with a clear message when something in the cart is no longer available" do
      user = create(:user)
      sign_in user
      product = create(:product, stock_quantity: 2)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 2)
      product.update!(stock_quantity: 0)

      get checkout_path

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).to include("no longer available")
    end

    it "disables Turbo on the checkout form — Turbo's fetch-based submission can't hand off a cross-origin redirect to Stripe as a real browser navigation, so without this the card payment button just reloads the page instead of ever reaching Stripe" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00)
      post cart_items_path, params: { product_id: product.slug }

      get checkout_path

      expect(response.body).to match(%r{<form[^>]*data-turbo="false"[^>]*action="/checkout"})
    end

    it "doesn't nest the coupon form inside the checkout form — nested <form> elements are invalid HTML, and a browser silently collapses them into the outer one, which previously made clicking the coupon's own Remove/Apply button submit the checkout form instead" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00)
      post cart_items_path, params: { product_id: product.slug }

      get checkout_path

      doc = Nokogiri::HTML::Document.parse(response.body)
      checkout_form = doc.at_css('form[action="/checkout"]')
      expect(checkout_form.css("form")).to be_empty
      expect(doc.at_css("#coupon-apply-form")).to be_present
      expect(doc.at_css("#coupon-remove-form")).to be_present
    end

    it "shows the real cart items and subtotal for a signed-in user" do
      user = create(:user)
      sign_in user
      product = create(:product, name: "Trailhawk Off-Road Scooter", price_cents: 100_00)
      post cart_items_path, params: { product_id: product.slug }

      get checkout_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Trailhawk Off-Road Scooter")
    end

    it "warns that an applied coupon isn't deducted from a Pay on Delivery order",
       vcr: { cassette_name: "checkouts/pay_on_delivery_coupon_warning" } do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00)
      post cart_items_path, params: { product_id: product.slug }
      coupon = create(:coupon, code: "PODWARN20")
      Payments::CouponSync.create(coupon)
      post cart_coupon_path, params: { code: coupon.code }

      get checkout_path

      expect(response.body).to include("PODWARN20")
      expect(response.body).to include("isn't applied to Pay on Delivery orders")
    end
  end

  describe "POST /checkout" do
    it "creates a real order and redirects to a real confirmation page" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug, quantity: 2 }

      expect { post checkout_path, params: shipping_params }.to change(Order, :count).by(1)

      order = user.orders.sole
      expect(response).to redirect_to(checkout_confirmation_path(order.order_number))
      expect(order.total_cents).to eq(200_00)
      expect(product.reload.stock_quantity).to eq(3)
      expect(user.reload.cart.cart_items).to be_empty
    end

    it "charges the real AED amount and shows an AED-only confirmation page even when the visitor was shopping in USD — the display currency never touches the actual order" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      ExchangeRate.create!(usd_per_aed: 0.272294, fetched_at: Time.current)
      cookies[:currency] = "USD"
      post cart_items_path, params: { product_id: product.slug, quantity: 2 }

      post checkout_path, params: shipping_params
      order = user.orders.sole

      expect(order.total_cents).to eq(200_00)
      follow_redirect!
      # Scoped to the order summary card itself, not the whole page — the
      # header's mega-menu legitimately shows *other* products' prices
      # converted to USD (it's shopping content on every page); what must
      # never happen is this order's own receipt showing a dollar figure.
      order_summary = Nokogiri::HTML::Document.parse(response.body).at_css("div.mt-10.text-left")
      expect(order_summary.text).to include("AED 200")
      expect(order_summary.text).not_to match(/\$[\d,]+\.\d{2}/)
    end

    it "saves the entered address for next time when requested" do
      user = create(:user)
      sign_in user
      product = create(:product, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      expect {
        post checkout_path, params: shipping_params.merge(save_address: "1")
      }.to change(user.addresses, :count).by(1)

      saved = user.addresses.sole
      expect(saved.full_name).to eq("Layla Ahmed")
      expect(saved.default_address).to be true
    end

    it "does not save an address when not requested" do
      user = create(:user)
      sign_in user
      product = create(:product, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      expect { post checkout_path, params: shipping_params }.not_to change(Address, :count)
    end

    it "applies gift wrap cost when requested" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      post checkout_path, params: shipping_params.merge(gift_wrap: "1")

      expect(user.orders.sole.total_cents).to eq(100_00 + CartsController::GIFT_WRAP_CENTS)
    end

    it "saves the gift wrap sticker name alongside the gift wrap charge" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      post checkout_path, params: shipping_params.merge(gift_wrap: "1", gift_wrap_name: "Happy Birthday, Sara!")

      order = user.orders.sole
      expect(order.gift_wrap_name).to eq("Happy Birthday, Sara!")
      expect(order.gift_wrap_cents).to eq(CartsController::GIFT_WRAP_CENTS)
    end

    it "ignores a gift wrap name when gift wrap itself wasn't checked" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      post checkout_path, params: shipping_params.merge(gift_wrap_name: "Should be ignored")

      order = user.orders.sole
      expect(order.gift_wrap_cents).to eq(0)
      expect(order.gift_wrap_name).to be_nil
    end

    it "defaults to free standard delivery" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      post checkout_path, params: shipping_params

      order = user.orders.sole
      expect(order.delivery_method).to eq("standard")
      expect(order.total_cents).to eq(100_00)
    end

    it "applies the express delivery fee when requested" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      post checkout_path, params: shipping_params.merge(delivery_method: "express")

      order = user.orders.sole
      expect(order.delivery_method).to eq("express")
      expect(order.total_cents).to eq(100_00 + CartsController::EXPRESS_DELIVERY_CENTS)
    end

    it "combines gift wrap and express delivery in the same order total" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      post checkout_path, params: shipping_params.merge(gift_wrap: "1", delivery_method: "express")

      order = user.orders.sole
      expect(order.total_cents).to eq(100_00 + CartsController::GIFT_WRAP_CENTS + CartsController::EXPRESS_DELIVERY_CENTS)
    end

    it "redirects to the cart with an error when stock ran out" do
      user = create(:user)
      sign_in user
      product = create(:product, stock_quantity: 1)
      post cart_items_path, params: { product_id: product.slug, quantity: 1 }
      product.update!(stock_quantity: 0) # ran out between adding to cart and checking out

      post checkout_path, params: shipping_params

      expect(response).to redirect_to(cart_path)
      expect(Order.count).to eq(0)
    end

    it "redirects to the cart with a clear message, not a 500, when the cart was already checked out (e.g. a double-submitted request)" do
      user = create(:user)
      sign_in user
      product = create(:product, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }
      allow(Order).to receive(:create_from_cart!).and_raise(Order::AlreadyCheckedOut)

      post checkout_path, params: shipping_params

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).to include("already placed")
    end

    it "re-renders the form with errors for missing shipping details" do
      user = create(:user)
      sign_in user
      product = create(:product, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      post checkout_path, params: shipping_params.merge(shipping_emirate: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(Order.count).to eq(0)
    end
  end

  describe "POST /checkout with payment_method=card" do
    it "creates an awaiting_payment order and redirects to Stripe's hosted page",
       vcr: { cassette_name: "checkouts/card_payment_redirects_to_stripe" } do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      post checkout_path, params: {
        payment_method: "card", shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
        shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai", shipping_emirate: "Dubai"
      }

      order = Order.last
      expect(order.payment_method).to eq("card")
      expect(order.status).to eq("awaiting_payment")
      expect(response).to redirect_to(a_string_starting_with("https://checkout.stripe.com/"))
    end

    it "shows a friendly error and creates nothing if Stripe can't be reached" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)
      # This user has no stripe_customer_id yet, so CreateCardOrder's
      # stripe_customer_id would otherwise call the real Stripe::Customer.create
      # (to provision one) before ever reaching Stripe::Checkout::Session.create
      # below — that's a real network call this un-vcr'd example must not make.
      allow(Stripe::Customer).to receive(:create).and_return(double("Stripe::Customer", id: "cus_test123"))
      allow(Stripe::Checkout::Session).to receive(:create).and_raise(Stripe::APIConnectionError.new("simulated"))

      expect {
        post checkout_path, params: {
          payment_method: "card", shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
          shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai", shipping_emirate: "Dubai"
        }
      }.not_to change(Order, :count)

      expect(response).to redirect_to(cart_path)
      expect(flash[:alert]).to match(/couldn't start your card payment/i)
    end

    it "sends the exact gift wrap and express delivery amounts to Stripe as separate line items" do
      user = create(:user, stripe_customer_id: "cus_existing123")
      sign_in user
      product = create(:product, name: "Trailhawk Off-Road Scooter", price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      sent_line_items = nil
      allow(Stripe::Checkout::Session).to receive(:create) do |params|
        sent_line_items = params[:line_items]
        double("Stripe::Checkout::Session", id: "cs_test_123", url: "https://checkout.stripe.com/pay/cs_test_123")
      end

      post checkout_path, params: {
        payment_method: "card", gift_wrap: "1", gift_wrap_name: "For Ahmed", delivery_method: "express",
        shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
        shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai", shipping_emirate: "Dubai"
      }

      expect(response).to redirect_to("https://checkout.stripe.com/pay/cs_test_123")

      order = user.orders.sole
      expect(order.gift_wrap_cents).to eq(CartsController::GIFT_WRAP_CENTS)
      expect(order.gift_wrap_name).to eq("For Ahmed")
      expect(order.delivery_fee_cents).to eq(CartsController::EXPRESS_DELIVERY_CENTS)
      expect(order.total_cents).to eq(10_000 + CartsController::GIFT_WRAP_CENTS + CartsController::EXPRESS_DELIVERY_CENTS)

      expect(sent_line_items.length).to eq(3)
      expect(sent_line_items[0][:price_data][:unit_amount]).to eq(10_000)
      expect(sent_line_items[0][:price_data][:product_data][:name]).to eq("Trailhawk Off-Road Scooter")

      gift_wrap_item = sent_line_items.find { |li| li[:price_data][:product_data][:name].start_with?("Gift wrap") }
      expect(gift_wrap_item[:price_data][:unit_amount]).to eq(CartsController::GIFT_WRAP_CENTS)
      expect(gift_wrap_item[:price_data][:product_data][:name]).to eq("Gift wrap (For Ahmed)")

      delivery_item = sent_line_items.find { |li| li[:price_data][:product_data][:name] == "Express delivery" }
      expect(delivery_item[:price_data][:unit_amount]).to eq(CartsController::EXPRESS_DELIVERY_CENTS)

      total_sent_to_stripe = sent_line_items.sum { |li| li[:price_data][:unit_amount] * li[:quantity] }
      expect(total_sent_to_stripe).to eq(order.total_cents)
    end

    it "still charges Stripe the real AED amount when the visitor was shopping in USD — the display currency never reaches the payment" do
      user = create(:user, stripe_customer_id: "cus_existing123")
      sign_in user
      product = create(:product, name: "Trailhawk Off-Road Scooter", price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)
      ExchangeRate.create!(usd_per_aed: 0.272294, fetched_at: Time.current)
      cookies[:currency] = "USD"

      sent_line_items = nil
      allow(Stripe::Checkout::Session).to receive(:create) do |params|
        sent_line_items = params[:line_items]
        double("Stripe::Checkout::Session", id: "cs_test_123", url: "https://checkout.stripe.com/pay/cs_test_123")
      end

      post checkout_path, params: {
        payment_method: "card", shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
        shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai", shipping_emirate: "Dubai"
      }

      expect(sent_line_items[0][:price_data][:currency]).to eq("aed")
      expect(sent_line_items[0][:price_data][:unit_amount]).to eq(10_000)
      expect(user.orders.sole.total_cents).to eq(10_000)
    end
  end

  describe "GET /checkout/confirmation/:order_number" do
    it "shows the signed-in user's own order" do
      user = create(:user)
      order = create(:order, user: user)

      sign_in user
      get checkout_confirmation_path(order.order_number)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(order.order_number)
    end

    it "404s for another user's order" do
      owner = create(:order).user
      other_user = create(:user)

      sign_in other_user
      get checkout_confirmation_path(owner.orders.sole.order_number)

      expect(response).to have_http_status(:not_found)
    end
  end
end
