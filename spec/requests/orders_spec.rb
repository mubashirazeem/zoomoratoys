require "rails_helper"

RSpec.describe "Orders", type: :request do
  describe "GET /account/orders" do
    it "redirects an anonymous visitor to sign in" do
      get account_orders_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows an empty state for a signed-in user with no orders" do
      sign_in create(:user)

      get account_orders_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("You haven't placed any orders yet")
    end

    it "renders the order history list without crashing for every possible order status" do
      user = create(:user)
      Order.statuses.each_key do |status|
        create(:order, user: user, status: status, order_number: "ZT-#{status}")
      end
      sign_in user

      get account_orders_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Awaiting payment")
      expect(response.body).to include("Refunded")
    end

    it "shows only the current user's orders, newest first" do
      user = create(:user)
      other_user = create(:user)
      older = create(:order, user: user, order_number: "ZT-000001", placed_at: 2.days.ago)
      newer = create(:order, user: user, order_number: "ZT-000002", placed_at: 1.hour.ago)
      create(:order, user: other_user, order_number: "ZT-000003")
      sign_in user

      get account_orders_path

      expect(response.body).to include("ZT-000001")
      expect(response.body).to include("ZT-000002")
      expect(response.body).not_to include("ZT-000003")
      expect(response.body.index(newer.order_number)).to be < response.body.index(older.order_number)
    end
  end

  describe "GET /orders/:id" do
    it "redirects an anonymous visitor to sign in" do
      order = create(:order)

      get order_path(order)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the order's line items, status, and shipping details to its owner" do
      user = create(:user)
      order = create(:order, user: user, order_number: "ZT-000010", status: "shipped")
      line_item = create(:line_item, order: order, quantity: 2, price_cents: 5_000)
      sign_in user

      get order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("ZT-000010")
      expect(response.body).to include(line_item.product.name)
      expect(response.body).to include(order.shipping_name)
    end

    it "shows a real, no-login-required Stripe invoice link to the order's own customer" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "card", status: "processing",
                              stripe_payment_intent_id: "pi_x", stripe_hosted_invoice_url: "https://invoice.stripe.com/i/acct_test/test_receipt")
      sign_in user

      get order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("https://invoice.stripe.com/i/acct_test/test_receipt")
    end

    it "shows a partial refund to the order's own customer" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "card", status: "processing",
                              stripe_payment_intent_id: "pi_x", refunded_cents: 5_000)
      sign_in user

      get order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Partially refunded")
    end

    it "shows no invoice link for an order that has none yet" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "pay_on_delivery")
      sign_in user

      get order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("View Invoice")
    end

    it "404s when a signed-in user requests another user's order" do
      order = create(:order)
      intruder = create(:user)
      sign_in intruder

      get order_path(order)

      expect(response).to have_http_status(:not_found)
    end

    it "renders an awaiting_payment order without crashing, with a waiting message instead of the fulfillment stepper" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "card", status: "awaiting_payment")
      sign_in user

      get order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Awaiting payment")
      expect(response.body).not_to include("This order was cancelled")
    end

    it "renders a refunded order without crashing, with a refunded message instead of the fulfillment stepper" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "card", status: "refunded",
                              stripe_payment_intent_id: "pi_x", refunded_cents: 10_000, total_cents: 10_000)
      sign_in user

      get order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Refunded")
      expect(response.body).to include("This order was refunded")
    end

    it "shows a Complete Payment button for an awaiting_payment card order" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "card", status: "awaiting_payment")
      sign_in user

      get order_path(order)

      expect(response.body).to include("Complete Payment")
    end

    it "disables Turbo on the Complete Payment form — same reason as the checkout form: a fetch-based redirect can't hand off a cross-origin Stripe URL to a real browser navigation, so without this the button just reloads the page instead of ever reaching Stripe" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "card", status: "awaiting_payment")
      sign_in user

      get order_path(order)

      expect(response.body).to match(%r{<form[^>]*data-turbo="false"[^>]*action="/account/orders/#{order.id}/resume_payment"})
    end
  end

  describe "POST /account/orders/:id/resume_payment" do
    it "redirects an anonymous visitor to sign in" do
      order = create(:order)

      post resume_payment_order_path(order)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "sends a still-awaiting-payment card order to a real Stripe Checkout URL",
       vcr: { cassette_name: "orders/resume_payment/redirects_to_stripe" } do
      user = create(:user)
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      order = create(:order, user: user, payment_method: "card", status: "awaiting_payment",
                              total_cents: 10_000, subtotal_cents: 10_000)
      create(:line_item, order: order, product: product, quantity: 1, price_cents: 10_000)
      sign_in user

      post resume_payment_order_path(order)

      expect(response).to redirect_to(a_string_starting_with("https://checkout.stripe.com/"))
      expect(order.reload.stripe_checkout_session_id).to be_present
    end

    it "refuses to resume a Pay on Delivery order — there's no Stripe payment to restart" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "pay_on_delivery", status: "pending")
      sign_in user

      post resume_payment_order_path(order)

      expect(response).to redirect_to(order_path(order))
      follow_redirect!
      expect(response.body).to include("can&#39;t be resumed")
    end

    it "refuses to resume a card order that's already past awaiting_payment" do
      user = create(:user)
      order = create(:order, user: user, payment_method: "card", status: "pending")
      sign_in user

      post resume_payment_order_path(order)

      expect(response).to redirect_to(order_path(order))
      follow_redirect!
      expect(response.body).to include("can&#39;t be resumed")
    end

    it "404s when a signed-in user tries to resume another user's order" do
      order = create(:order, payment_method: "card", status: "awaiting_payment")
      intruder = create(:user)
      sign_in intruder

      post resume_payment_order_path(order)

      expect(response).to have_http_status(:not_found)
    end
  end
end
