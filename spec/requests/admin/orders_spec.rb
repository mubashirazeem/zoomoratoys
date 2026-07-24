require "rails_helper"

RSpec.describe "Admin::Orders", type: :request do
  describe "GET /admin/orders" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_orders_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "updates an order's status" do
      order = create(:order, status: "pending")

      patch admin_order_path(order), params: { order: { status: "shipped" } }

      expect(order.reload.status).to eq("shipped")
      expect(response).to redirect_to(admin_order_path(order))
    end

    it "still allows a normal, legitimate manual status update" do
      order = create(:order, status: "processing")

      patch admin_order_path(order), params: { order: { status: "shipped" } }

      expect(order.reload.status).to eq("shipped")
      expect(response).to redirect_to(admin_order_path(order))
      expect(flash[:notice]).to eq("Order status updated to Shipped.")
    end

    it "restores stock when an unshipped order is manually cancelled" do
      product = create(:product, stock_quantity: 2, stock_status: "in_stock")
      order = create(:order, status: "processing")
      create(:line_item, order: order, product: product, quantity: 1)
      product.decrement!(:stock_quantity, 1)
      product.sync_stock_status!

      patch admin_order_path(order), params: { order: { status: "cancelled" } }

      expect(order.reload.status).to eq("cancelled")
      expect(product.reload.stock_quantity).to eq(2)
      expect(product.reload.stock_status).to eq("in_stock")
    end

    it "does not restore stock when a shipped order is manually cancelled — those units are already with the customer" do
      product = create(:product, stock_quantity: 1, stock_status: "in_stock")
      order = create(:order, status: "shipped")
      create(:line_item, order: order, product: product, quantity: 1)

      patch admin_order_path(order), params: { order: { status: "cancelled" } }

      expect(order.reload.status).to eq("cancelled")
      expect(product.reload.stock_quantity).to eq(1)
    end

    it "does not double-restore stock if an already-cancelled order's form is resubmitted" do
      product = create(:product, stock_quantity: 2, stock_status: "in_stock")
      order = create(:order, status: "cancelled")
      create(:line_item, order: order, product: product, quantity: 1)
      product.decrement!(:stock_quantity, 1)
      product.sync_stock_status!

      patch admin_order_path(order), params: { order: { status: "cancelled" } }

      expect(product.reload.stock_quantity).to eq(1)
    end

    it "does not restore stock for a normal status change that isn't a cancellation" do
      product = create(:product, stock_quantity: 2, stock_status: "in_stock")
      order = create(:order, status: "processing")
      create(:line_item, order: order, product: product, quantity: 1)
      product.decrement!(:stock_quantity, 1)
      product.sync_stock_status!

      patch admin_order_path(order), params: { order: { status: "shipped" } }

      expect(product.reload.stock_quantity).to eq(1)
    end

    it "rejects a direct attempt to set the system-managed refunded status" do
      order = create(:order, status: "processing")

      patch admin_order_path(order), params: { order: { status: "refunded" } }

      expect(order.reload.status).to eq("processing")
      expect(response).to redirect_to(admin_order_path(order))
      expect(flash[:alert]).to include("refunded")
    end

    it "rejects a direct attempt to set the system-managed awaiting_payment status" do
      order = create(:order, status: "processing")

      patch admin_order_path(order), params: { order: { status: "awaiting_payment" } }

      expect(order.reload.status).to eq("processing")
      expect(response).to redirect_to(admin_order_path(order))
      expect(flash[:alert]).to include("awaiting_payment")
    end

    it "refuses to change the status of an awaiting_payment order, even to a legitimate-looking target" do
      order = create(:order, payment_method: "card", status: "awaiting_payment")

      patch admin_order_path(order), params: { order: { status: "pending" } }

      expect(order.reload.status).to eq("awaiting_payment")
    end

    it "refuses to change the status of a refunded order" do
      order = create(:order, payment_method: "card", status: "refunded", stripe_payment_intent_id: "pi_x", refunded_cents: 10_000, total_cents: 10_000)

      patch admin_order_path(order), params: { order: { status: "pending" } }

      expect(order.reload.status).to eq("refunded")
    end

    it "still allows a legitimate status change between manually-settable statuses" do
      order = create(:order, status: "processing")

      patch admin_order_path(order), params: { order: { status: "shipped" } }

      expect(order.reload.status).to eq("shipped")
    end

    it "shows a real, webhook-confirmed Paid status and links to the payment and invoice on Stripe for a paid card order" do
      order = create(:order, payment_method: "card", status: "processing",
                              stripe_payment_intent_id: "pi_real123", stripe_invoice_id: "in_real456")

      get admin_order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Payment Status")
      expect(response.body).to include("Paid")
      expect(response.body).to include("https://dashboard.stripe.com/test/payments/pi_real123")
      expect(response.body).to include("https://dashboard.stripe.com/test/invoices/in_real456")
    end

    it "warns the admin that changing status doesn't refund a paid card order" do
      order = create(:order, payment_method: "card", status: "processing", stripe_payment_intent_id: "pi_real123")

      get admin_order_path(order)

      expect(response.body).to include("does <strong>not</strong> refund the customer")
    end

    it "shows no refund warning for a Pay on Delivery order — there's no Stripe payment to warn about" do
      order = create(:order, payment_method: "pay_on_delivery", status: "processing")

      get admin_order_path(order)

      expect(response.body).not_to include("does <strong>not</strong> refund the customer")
    end

    it "shows no refund warning once the order is already refunded — the warning is only relevant while it's still paid and unresolved" do
      order = create(:order, payment_method: "card", status: "refunded", stripe_payment_intent_id: "pi_real123",
                              refunded_cents: 10_000, total_cents: 10_000)

      get admin_order_path(order)

      expect(response.body).not_to include("does <strong>not</strong> refund the customer")
    end

    it "shows a clear dispute warning when the order has an open Stripe dispute" do
      order = create(:order, payment_method: "card", status: "processing", stripe_payment_intent_id: "pi_real123",
                              stripe_dispute_status: "needs_response")

      get admin_order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Disputed on Stripe")
      expect(response.body).to include("Needs response")
    end

    it "shows no dispute warning for an order that's never been disputed" do
      order = create(:order, payment_method: "card", status: "processing", stripe_payment_intent_id: "pi_real123")

      get admin_order_path(order)

      expect(response.body).not_to include("Disputed on Stripe")
    end

    it "shows the real, no-login-required Stripe invoice receipt link alongside the Dashboard link" do
      order = create(:order, payment_method: "card", status: "processing", stripe_payment_intent_id: "pi_real123",
                              stripe_hosted_invoice_url: "https://invoice.stripe.com/i/acct_test/test_receipt")

      get admin_order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("https://invoice.stripe.com/i/acct_test/test_receipt")
    end

    it "shows a partial-refund message, not the Refund button, for a card order that's only been partially refunded" do
      order = create(:order, payment_method: "card", status: "processing", stripe_payment_intent_id: "pi_real123",
                              refunded_cents: 5_000, total_cents: 20_000)

      get admin_order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Partially refunded")
      expect(response.body).not_to include(">Refund<")
    end

    it "shows Awaiting payment instead of a misleading blank status for a card order still waiting on Stripe" do
      order = create(:order, payment_method: "card", status: "awaiting_payment")

      get admin_order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Awaiting payment")
    end

    it "shows no Payment Status section at all for a Pay on Delivery order — there's no Stripe payment to report on" do
      order = create(:order, payment_method: "pay_on_delivery", status: "pending")

      get admin_order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Payment Status")
    end

    it "renders the order list without crashing for every possible order status, including the system-managed ones" do
      Order.statuses.each_key do |status|
        create(:order, status: status, order_number: "ZT-#{status}")
      end

      get admin_orders_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Awaiting payment")
      expect(response.body).to include("Refunded")
    end

    it "filters the order list by status" do
      pending_order = create(:order, status: "pending", order_number: "ZT-P1")
      shipped_order = create(:order, status: "shipped", order_number: "ZT-S1")

      get admin_orders_path(status: "shipped")

      expect(response.body).to include(shipped_order.order_number)
      expect(response.body).not_to include(pending_order.order_number)
    end

    it "searches orders by order number or customer name/email" do
      customer = create(:user, first_name: "Layla", last_name: "Ahmed", email: "layla@example.com")
      matching = create(:order, user: customer, order_number: "ZT-M1")
      other = create(:order, order_number: "ZT-O1")

      get admin_orders_path(q: "layla")

      expect(response.body).to include(matching.order_number)
      expect(response.body).not_to include(other.order_number)
    end

    it "renders a packing slip with shipping details and quantities but no prices" do
      order = create(:order, total_cents: 21_500)
      line_item = create(:line_item, order: order, quantity: 2, price_cents: 10_000)

      get packing_slip_admin_order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(order.order_number)
      expect(response.body).to include(order.shipping_name)
      expect(response.body).to include(line_item.product.name)
      expect(response.body).not_to include("AED 100")
      expect(response.body).to include(Admin::OrdersController::INVOICE_ACCOUNTS_EMAIL)
      expect(response.body).to include(Admin::OrdersController::INVOICE_SALES_EMAIL)
      expect(response.body).to include(Admin::OrdersController::INVOICE_MOBILE)
    end

    it "renders an invoice with prices, totals, VAT breakdown, and invoice contact details" do
      order = create(:order, total_cents: 21_500, subtotal_cents: 20_000, gift_wrap_cents: 1_500)
      line_item = create(:line_item, order: order, quantity: 2, price_cents: 10_000)

      get invoice_admin_order_path(order)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(order.order_number)
      expect(response.body).to include(line_item.product.name)
      expect(response.body).to include("AED 215")
      expect(response.body).to include(order.payment_method.humanize)
      expect(response.body).to include(Admin::OrdersController::INVOICE_ACCOUNTS_EMAIL)
      expect(response.body).to include(Admin::OrdersController::INVOICE_SALES_EMAIL)
      expect(response.body).to include(Admin::OrdersController::INVOICE_MOBILE)
      # 21_500 total, VAT-inclusive: 21_500 / 1.05 = 20_476.19 cents, rounds
      # to AED 204.76 excl. VAT + AED 10.24 VAT — verifies fils-precision
      # math, not the truncated whole-AED display format_aed uses elsewhere.
      expect(response.body).to include("AED 204.76")
      expect(response.body).to include("AED 10.24")
    end

    it "shows a discount line on the invoice when the order has one" do
      order = create(:order, discount_cents: 2_000, total_cents: 8_000)
      create(:line_item, order: order, quantity: 1, price_cents: 10_000)

      get invoice_admin_order_path(order)

      expect(response.body).to include("Discount")
      expect(response.body).to include("AED 20")
    end

    it "shows the same number for the order and its invoice — one field, no separate invoice number" do
      order = create(:order)

      get invoice_admin_order_path(order)

      expect(response.body.scan(order.order_number).size).to be >= 2
    end

    it "shows the Stripe payment reference on the invoice for a card order" do
      order = create(:order, payment_method: "card", stripe_payment_intent_id: "pi_test_visible", total_cents: 10_000)
      create(:line_item, order: order, quantity: 1, price_cents: 10_000)

      get invoice_admin_order_path(order)

      expect(response.body).to include("pi_test_visible")
    end

    it "shows no Stripe reference on the invoice for a Pay on Delivery order" do
      order = create(:order, payment_method: "pay_on_delivery", total_cents: 10_000)
      create(:line_item, order: order, quantity: 1, price_cents: 10_000)

      get invoice_admin_order_path(order)

      expect(response.body).not_to include("Paid via Stripe")
    end

    it "refunds a card order", vcr: { cassette_name: "admin/orders/refund_success" } do
      # A real, confirmed test-mode PaymentIntent — created here (and
      # recorded into the same cassette as the refund itself) so the
      # controller action refunds a payment_intent id that genuinely exists.
      payment_intent = Stripe::PaymentIntent.create(
        amount: 10_000, currency: "aed", payment_method: "pm_card_visa",
        confirm: true, automatic_payment_methods: { enabled: true, allow_redirects: "never" }
      )
      order = create(:order, payment_method: "card", status: "processing",
                              stripe_payment_intent_id: payment_intent.id, total_cents: 10_000)

      post refund_admin_order_path(order)

      expect(response).to redirect_to(admin_order_path(order))
      order.reload
      expect(order.status).to eq("refunded")
      expect(order.refunded_cents).to eq(10_000)
    end

    it "refuses to refund a Pay on Delivery order" do
      order = create(:order, payment_method: "pay_on_delivery", status: "processing")

      post refund_admin_order_path(order)

      expect(response).to redirect_to(admin_order_path(order))
      expect(order.reload.status).to eq("processing")
    end

    it "refuses to refund an order that's already been refunded" do
      order = create(:order, payment_method: "card", status: "refunded",
                              stripe_payment_intent_id: "pi_x", refunded_cents: 10_000, total_cents: 10_000)

      post refund_admin_order_path(order)

      expect(response).to redirect_to(admin_order_path(order))
    end
  end
end
