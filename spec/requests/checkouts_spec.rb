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

    it "includes gift wrap and express delivery in the displayed Total — Tabby's own QA caught this staying at the bare subtotal" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00)
      post cart_items_path, params: { product_id: product.slug }

      get checkout_path, params: { gift_wrap: "1", delivery_method: "express" }

      # AED 100 subtotal + AED 50 gift wrap + AED 100 express delivery = AED 250
      expect(response.body).to include("AED 250")
      expect(response.body).not_to include("+ gift wrap / express delivery if selected")
    end

    it "shows the AED equivalent next to the USD total, and notes Tabby charges in AED, when shopping in USD — Tabby's own QA asked for both" do
      user = create(:user)
      sign_in user
      create(:address, user: user, phone: "+971501234567", default_address: true)
      product = create(:product, price_cents: 100_00)
      ExchangeRate.create!(usd_per_aed: 0.272294, fetched_at: Time.current)
      cookies[:currency] = "USD"
      post cart_items_path, params: { product_id: product.slug }

      get checkout_path

      # AED 100 -> $27.23 at this rate; the AED figure must still be on
      # screen somewhere so the customer can see what Tabby will actually
      # charge before they ever redirect.
      expect(response.body).to include("$27.23 USD")
      expect(response.body).to include("(AED 100)")
      expect(response.body).to include("Tabby processes your payment in AED")
    end

    it "hides Tabby as a selectable payment method and shows the rejection message when background pre-scoring rejects the customer" do
      user = create(:user)
      sign_in user
      create(:address, user: user, phone: "+971501234567", default_address: true)
      product = create(:product, price_cents: 100_00)
      post cart_items_path, params: { product_id: product.slug }
      allow(Payments::Tabby).to receive(:post).and_return({
        "status" => "rejected",
        "configuration" => { "products" => { "installments" => { "is_available" => false, "rejection_reason" => "not_available" } } }
      })

      get checkout_path

      doc = Nokogiri::HTML::Document.parse(response.body)
      tabby_radio = doc.at_css('input[name="payment_method"][value="tabby"]')
      expect(tabby_radio["disabled"]).to be_present
      expect(response.body).to include("Tabby isn&#39;t available for this order right now.")
    end

    it "still shows Tabby normally when background pre-scoring approves the customer" do
      user = create(:user)
      sign_in user
      create(:address, user: user, phone: "+971501234567", default_address: true)
      product = create(:product, price_cents: 100_00)
      post cart_items_path, params: { product_id: product.slug }
      allow(Payments::Tabby).to receive(:post).and_return({ "status" => "created" })

      get checkout_path

      doc = Nokogiri::HTML::Document.parse(response.body)
      tabby_radio = doc.at_css('input[name="payment_method"][value="tabby"]')
      expect(tabby_radio["disabled"]).to be_nil
    end

    it "restores the cart and releases the stock reservation when a customer bounces back from a cancelled/failed Tabby attempt" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      order = create(:order, user: user, payment_method: "tabby", status: "awaiting_payment",
                              total_cents: 100_00, subtotal_cents: 100_00, tabby_payment_id: "pay_abandoned")
      create(:line_item, order: order, product: product, quantity: 1, price_cents: 100_00)
      product.decrement!(:stock_quantity, 1) # mirrors the reservation Order.create_from_cart! would have made

      get checkout_path, params: { tabby_recover: order.order_number }

      expect(response).to have_http_status(:success)
      expect(user.cart.cart_items.sole.product).to eq(product)
      expect(user.cart.cart_items.sole.quantity).to eq(1)
      expect(order.reload.status).to eq("cancelled")
      expect(product.reload.stock_quantity).to eq(5)
      # The real bug Tabby's own QA caught: ApplicationController#set_cart
      # runs before this recovery (it's a parent-class before_action) and
      # computed @cart_subtotal_cents from the cart while it was still
      # empty — showing "AED 0" until a manual reload recomputed it.
      expect(response.body).to include("AED 100")
      expect(response.body).not_to include("AED 0")
      # Tabby's cancel/failure redirect carries no shipping form data at
      # all — without falling back to the recovered order's own shipping
      # fields, the customer would have to retype their whole address
      # before they could actually complete the order another way.
      expect(response.body).to include(order.shipping_phone)
      expect(response.body).to include(CGI.escapeHTML(order.shipping_address_line1))
    end

    it "keeps gift wrap and Express Delivery selected (and in the displayed Total) after a Tabby cancel/failure — found by testing the full combination together, not each piece alone" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      order = create(:order, user: user, payment_method: "tabby", status: "awaiting_payment",
                              total_cents: 250_00, subtotal_cents: 100_00, gift_wrap_cents: 50_00,
                              delivery_method: "express", delivery_fee_cents: 100_00, tabby_payment_id: "pay_abandoned")
      create(:line_item, order: order, product: product, quantity: 1, price_cents: 100_00)

      get checkout_path, params: { tabby_recover: order.order_number }

      doc = Nokogiri::HTML::Document.parse(response.body)
      expect(doc.at_css('input[name="gift_wrap"]')["checked"]).to be_present
      expect(doc.at_css('input[name="delivery_method"][value="express"]')["checked"]).to be_present
      expect(response.body).to include("AED 250") # 100 subtotal + 50 gift wrap + 100 express — not the bare AED 100
    end

    it "shows a distinct message for a cancellation vs. a failure — Tabby's own QA caught that neither showed any message at all before" do
      user = create(:user)
      sign_in user
      order = create(:order, user: user, payment_method: "tabby", status: "awaiting_payment", tabby_payment_id: "pay_cancelled")
      create(:line_item, order: order, product: create(:product), quantity: 1)

      get checkout_path, params: { tabby_recover: order.order_number, tabby_outcome: "cancelled" }
      expect(response.body).to include("You aborted the payment")

      order2 = create(:order, user: user, payment_method: "tabby", status: "awaiting_payment", tabby_payment_id: "pay_failed")
      create(:line_item, order: order2, product: create(:product), quantity: 1)

      get checkout_path, params: { tabby_recover: order2.order_number, tabby_outcome: "failed" }
      expect(response.body).to include("unable to approve this purchase")
    end

    it "leaves an already-resolved order alone — a redelivered/late bounce-back must not double-restore stock" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      order = create(:order, user: user, payment_method: "tabby", status: "processing",
                              total_cents: 100_00, subtotal_cents: 100_00, tabby_payment_id: "pay_paid")
      create(:line_item, order: order, product: product, quantity: 1, price_cents: 100_00)
      cart_product = create(:product, price_cents: 50_00)
      post cart_items_path, params: { product_id: cart_product.slug }

      get checkout_path, params: { tabby_recover: order.order_number }

      expect(user.cart.cart_items.count).to eq(1)
      expect(user.cart.cart_items.sole.product).to eq(cart_product)
      expect(order.reload.status).to eq("processing")
      expect(product.reload.stock_quantity).to eq(5)
    end

    it "still restores the cart and shows the message when Tabby's rejected/expired webhook already cancelled the order before the browser redirect arrives — the real race that left rejection showing an empty cart with no message" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      order = create(:order, user: user, payment_method: "tabby", status: "awaiting_payment",
                              total_cents: 100_00, subtotal_cents: 100_00, tabby_payment_id: "pay_raced")
      create(:line_item, order: order, product: product, quantity: 1, price_cents: 100_00)
      # Simulate WebhookHandler#handle_failed winning the race: order
      # already cancelled + stock already restored before the customer's
      # browser gets here.
      order.update!(status: "cancelled")

      get checkout_path, params: { tabby_recover: order.order_number, tabby_outcome: "failed" }

      expect(user.cart.cart_items.sole.product).to eq(product)
      expect(response.body).to include("unable to approve this purchase")
      expect(product.reload.stock_quantity).to eq(5) # unchanged — webhook already restored it, this must not double-restore
    end

    it "does not double-add cart items on a second visit to the same recovery link" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      order = create(:order, user: user, payment_method: "tabby", status: "awaiting_payment",
                              total_cents: 100_00, subtotal_cents: 100_00, tabby_payment_id: "pay_revisit")
      create(:line_item, order: order, product: product, quantity: 1, price_cents: 100_00)
      product.decrement!(:stock_quantity, 1) # mirrors the reservation Order.create_from_cart! would have made

      get checkout_path, params: { tabby_recover: order.order_number }
      get checkout_path, params: { tabby_recover: order.order_number } # customer hits back/refresh on the same link

      expect(user.cart.cart_items.sole.quantity).to eq(1)
      expect(product.reload.stock_quantity).to eq(5)
    end

    it "still shows the preserved shipping details, delivery method, and gift wrap on a second visit to the same recovery link — a plain refresh must not blank the form even though the one-time cart-restore itself only runs once" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 100_00, stock_quantity: 5)
      order = create(:order, user: user, payment_method: "tabby", status: "awaiting_payment",
        total_cents: 150_00, subtotal_cents: 100_00, gift_wrap_cents: 50_00, delivery_method: "express",
        delivery_fee_cents: 0, tabby_payment_id: "pay_refresh",
        shipping_name: "Layla", shipping_phone: "+971500000000", shipping_address_line1: "Villa 1",
        shipping_city: "Dubai", shipping_emirate: "Dubai")
      create(:line_item, order: order, product: product, quantity: 1, price_cents: 100_00)
      product.decrement!(:stock_quantity, 1)

      get checkout_path, params: { tabby_recover: order.order_number, tabby_outcome: "failed" }
      get checkout_path, params: { tabby_recover: order.order_number, tabby_outcome: "failed" } # plain refresh

      expect(response.body).to include("Layla")
      expect(response.body).to include("Villa 1")
      expect(response.body).to match(/name="delivery_method" value="express"[^>]*checked/)
      expect(response.body).to match(/name="gift_wrap"[^>]*checked/)
      # The one-time flash message correctly does NOT repeat on a refresh —
      # only the underlying form/cart state must survive.
      expect(response.body).not_to include(CheckoutsController::RECOVERY_MESSAGES["failed"])
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

  describe "POST /checkout with payment_method=tabby" do
    it "creates an awaiting_payment order and redirects to Tabby's hosted page" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }
      allow(Payments::Tabby).to receive(:post).and_return({
        "payment" => { "id" => "pay_123" },
        "configuration" => { "available_products" => { "installments" => [ { "web_url" => "https://checkout.tabby.ai/pay_123" } ] } }
      })

      post checkout_path, params: {
        payment_method: "tabby", shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
        shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai", shipping_emirate: "Dubai"
      }

      order = Order.last
      expect(order.payment_method).to eq("tabby")
      expect(order.status).to eq("awaiting_payment")
      expect(order.tabby_payment_id).to eq("pay_123")
      expect(response).to redirect_to("https://checkout.tabby.ai/pay_123")
    end

    it "shows a friendly error and creates nothing if Tabby can't be reached" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }
      allow(Payments::Tabby).to receive(:post).and_raise(Payments::ProviderError, "simulated")

      expect {
        post checkout_path, params: {
          payment_method: "tabby", shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
          shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai", shipping_emirate: "Dubai"
        }
      }.not_to change(Order, :count)

      expect(response).to redirect_to(cart_path)
      expect(flash[:alert]).to match(/couldn't start your payment/i)
    end

    it "re-renders checkout with Tabby's own rejection message on a rejected session — not a redirect, not an error/Sentry alert" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }
      allow(Payments::Tabby).to receive(:post).and_return({
        "status" => "rejected",
        "configuration" => { "products" => { "installments" => { "is_available" => false, "rejection_reason" => "order_amount_too_high" } } }
      })
      expect(Sentry).not_to receive(:capture_exception)
      expect(Rails.logger).not_to receive(:error)

      expect {
        post checkout_path, params: {
          payment_method: "tabby", shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
          shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai", shipping_emirate: "Dubai"
        }
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("This order total is too high for Tabby")
      expect(product.reload.stock_quantity).to eq(5)
      expect(user.cart.cart_items.count).to eq(1)
    end
  end

  describe "POST /checkout with payment_method=tamara" do
    # Tamara isn't offered in the UI (no radio for it, see checkouts/show)
    # and its backend isn't part of this deploy — but nothing stops a
    # hand-crafted request from still sending payment_method=tamara. This
    # must degrade safely (Pay on Delivery, the same as any other
    # unrecognized value) rather than error, since Payments::Tamara isn't
    # guaranteed to even be loaded.
    it "falls back to Pay on Delivery instead of erroring on an unrecognized payment method" do
      user = create(:user)
      sign_in user
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      post cart_items_path, params: { product_id: product.slug }

      post checkout_path, params: {
        payment_method: "tamara", shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
        shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai", shipping_emirate: "Dubai"
      }

      order = Order.last
      expect(order.payment_method).to eq("pay_on_delivery")
      expect(order.status).to eq("pending")
      expect(response).to redirect_to(checkout_confirmation_path(order.order_number))
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
