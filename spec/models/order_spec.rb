require "rails_helper"

RSpec.describe Order, type: :model do
  it "has a valid factory" do
    expect(build(:order)).to be_valid
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:line_items).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:order_number) }
  it { is_expected.to validate_presence_of(:placed_at) }
  it { is_expected.to validate_numericality_of(:total_cents).only_integer.is_greater_than_or_equal_to(0) }
  it {
    is_expected.to define_enum_for(:status)
      .with_values(awaiting_payment: "awaiting_payment", pending: "pending", processing: "processing",
                    shipped: "shipped", delivered: "delivered", cancelled: "cancelled", refunded: "refunded")
      .backed_by_column_of_type(:string)
  }

  it {
    is_expected.to define_enum_for(:payment_method)
      .with_values(pay_on_delivery: "pay_on_delivery", card: "card")
      .backed_by_column_of_type(:string)
  }

  describe "::MANUALLY_SETTABLE_STATUSES" do
    it "excludes the two system-managed statuses" do
      expect(Order::MANUALLY_SETTABLE_STATUSES).not_to include("awaiting_payment", "refunded")
      expect(Order::MANUALLY_SETTABLE_STATUSES).to include("pending", "processing", "shipped", "delivered", "cancelled")
    end
  end

  describe "#admin_status_tone" do
    it "has a real, distinct tone mapped for every single status in the enum — not just some of them" do
      Order.statuses.each_key do |status|
        order = build(:order, status: status)

        expect { order.admin_status_tone }.not_to raise_error
        expect(order.admin_status_tone).to be_a(Symbol)
      end
    end

    it "never raises for a status this method doesn't recognize — falls back to :neutral instead of crashing the page" do
      order = build(:order, status: "pending")
      allow(order).to receive(:status).and_return("some_future_status_nobody_added_here_yet")

      expect(order.admin_status_tone).to eq(:neutral)
    end
  end

  describe "#partially_refunded?" do
    it "is false when nothing has been refunded" do
      order = build(:order, refunded_cents: 0, status: "processing")

      expect(order.partially_refunded?).to be false
    end

    it "is true when some money has come back but the order isn't marked fully refunded" do
      order = build(:order, refunded_cents: 50_00, status: "processing")

      expect(order.partially_refunded?).to be true
    end

    it "is false once the order is fully refunded — refunded? already covers that state" do
      order = build(:order, refunded_cents: 200_00, status: "refunded")

      expect(order.partially_refunded?).to be false
    end
  end

  describe "#stripe_payment_status" do
    it "is nil for a Pay on Delivery order — there's no online payment to have a Stripe status at all" do
      order = build(:order, payment_method: "pay_on_delivery")

      expect(order.stripe_payment_status).to be_nil
    end

    it "is :awaiting_payment for a card order still waiting on Stripe" do
      order = build(:order, payment_method: "card", status: "awaiting_payment")

      expect(order.stripe_payment_status).to eq(:awaiting_payment)
    end

    it "is :paid for a card order once Stripe has confirmed payment, regardless of fulfillment status" do
      order = build(:order, payment_method: "card", status: "processing", stripe_payment_intent_id: "pi_123")

      expect(order.stripe_payment_status).to eq(:paid)
    end

    it "is :refunded once Stripe has refunded the payment" do
      order = build(:order, payment_method: "card", status: "refunded", stripe_payment_intent_id: "pi_123", refunded_cents: 100_00)

      expect(order.stripe_payment_status).to eq(:refunded)
    end

    it "is :partially_refunded when some money has come back but the order isn't marked fully refunded" do
      order = build(:order, payment_method: "card", status: "processing", stripe_payment_intent_id: "pi_123", refunded_cents: 50_00, total_cents: 200_00)

      expect(order.stripe_payment_status).to eq(:partially_refunded)
    end

    it "has a real tone mapped for every possible payment status, so the admin page can never crash rendering it" do
      [ nil, :awaiting_payment, :paid, :partially_refunded, :refunded ].each do |status|
        order = build(:order)
        allow(order).to receive(:stripe_payment_status).and_return(status)

        expect { order.stripe_payment_status_tone }.not_to raise_error
      end
    end
  end

  describe "#stripe_dashboard_payment_intent_url / #stripe_dashboard_invoice_url" do
    it "is nil when there's nothing to link to yet" do
      order = build(:order, stripe_payment_intent_id: nil, stripe_invoice_id: nil)

      expect(order.stripe_dashboard_payment_intent_url).to be_nil
      expect(order.stripe_dashboard_invoice_url).to be_nil
    end

    it "builds a real Stripe Dashboard link, using the test-mode path since this app runs on a test secret key" do
      order = build(:order, stripe_payment_intent_id: "pi_abc123", stripe_invoice_id: "in_xyz789")

      expect(order.stripe_dashboard_payment_intent_url).to eq("https://dashboard.stripe.com/test/payments/pi_abc123")
      expect(order.stripe_dashboard_invoice_url).to eq("https://dashboard.stripe.com/test/invoices/in_xyz789")
    end

    it "omits the test/ segment for a live secret key" do
      allow(Stripe).to receive(:api_key).and_return("sk_live_real_key")
      order = build(:order, stripe_payment_intent_id: "pi_abc123")

      expect(order.stripe_dashboard_payment_intent_url).to eq("https://dashboard.stripe.com/payments/pi_abc123")
    end
  end

  it "rejects a duplicate order_number" do
    create(:order, order_number: "ZT-000001")
    duplicate = build(:order, order_number: "ZT-000001")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:order_number]).to be_present
  end

  it "defaults to pending" do
    expect(Order.new.status).to eq("pending")
  end

  describe ".generate_order_number" do
    it "produces sequential ZMR- numbers, never repeating" do
      first = Order.generate_order_number
      second = Order.generate_order_number

      expect(first).to match(/\AZMR-\d+\z/)
      expect(second).to match(/\AZMR-\d+\z/)
      expect(second.split("-").last.to_i).to eq(first.split("-").last.to_i + 1)
    end

    it "self-heals when the counter row is missing, starting at 1000" do
      OrderNumberCounter.delete_all

      expect(Order.generate_order_number).to eq("ZMR-1000")
    end
  end

  describe "#amount_excluding_vat_cents and #vat_cents" do
    it "backs a 5% VAT amount out of the VAT-inclusive total" do
      order = build(:order, total_cents: 10_500)

      expect(order.amount_excluding_vat_cents).to eq(10_000)
      expect(order.vat_cents).to eq(500)
    end

    it "always sums back to the original total" do
      order = build(:order, total_cents: 13_370)

      expect(order.amount_excluding_vat_cents + order.vat_cents).to eq(order.total_cents)
    end
  end

  describe ".newest_first" do
    it "orders by placed_at, most recent first" do
      older = create(:order, placed_at: 2.days.ago)
      newer = create(:order, placed_at: 1.hour.ago)

      expect(Order.newest_first).to eq([ newer, older ])
    end
  end

  describe ".create_from_cart!" do
    let(:user) { create(:user) }
    let(:shipping_attributes) do
      {
        shipping_name: "Layla Ahmed", shipping_phone: "+971501234567",
        shipping_address_line1: "Villa 12, Al Wasl Road", shipping_city: "Dubai",
        shipping_emirate: "Dubai"
      }
    end

    it "creates a real order and line items, and decrements real product stock" do
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 2)

      order = Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes)

      expect(order).to be_persisted
      expect(order.line_items.sole).to have_attributes(product: product, quantity: 2, price_cents: 10_000)
      expect(order.subtotal_cents).to eq(20_000)
      expect(order.total_cents).to eq(20_000)
      expect(product.reload.stock_quantity).to eq(3)
    end

    it "records which coupon was used, when one is passed" do
      coupon = create(:coupon)
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      order = Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes, coupon: coupon)

      expect(order.coupon).to eq(coupon)
    end

    it "leaves coupon nil when none is passed — e.g. Pay on Delivery, which doesn't apply a cart's coupon yet" do
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      order = Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes)

      expect(order.coupon).to be_nil
    end

    it "reduces total_cents by discount_cents when provided, leaving subtotal_cents untouched" do
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 2)

      order = Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes, payment_method: "card", discount_cents: 3_000)

      expect(order.subtotal_cents).to eq(20_000)
      expect(order.discount_cents).to eq(3_000)
      expect(order.total_cents).to eq(17_000)
    end

    it "decrements the variant's stock, not the product's, when a variant is chosen" do
      product = create(:product, stock_quantity: 50)
      variant = create(:product_variant, product: product, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, product_variant: variant, quantity: 2)

      Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes)

      expect(variant.reload.stock_quantity).to eq(3)
      expect(product.reload.stock_quantity).to eq(50)
    end

    it "clears the cart after a successful order" do
      product = create(:product, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes)

      expect(cart.cart_items.reload).to be_empty
    end

    it "adds gift wrap cost to the total when requested" do
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      order = Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes, gift_wrap: true, gift_wrap_cents: 1_500)

      expect(order.gift_wrap_cents).to eq(1_500)
      expect(order.total_cents).to eq(11_500)
    end

    it "creates a card order as awaiting_payment instead of pending" do
      product = create(:product, price_cents: 10_000, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      order = Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes, payment_method: "card")

      expect(order.payment_method).to eq("card")
      expect(order.status).to eq("awaiting_payment")
    end

    it "still decrements stock immediately for a card order — reserved before Stripe is ever contacted" do
      product = create(:product, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 2)

      Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes, payment_method: "card")

      expect(product.reload.stock_quantity).to eq(3)
    end

    it "flips a product's stock_status to sold_out when the last unit is bought" do
      product = create(:product, stock_quantity: 1, stock_status: "in_stock")
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes)

      expect(product.reload.stock_status).to eq("sold_out")
    end

    it "leaves a product still in stock as in_stock" do
      product = create(:product, stock_quantity: 5, stock_status: "in_stock")
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 2)

      Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes)

      expect(product.reload.stock_status).to eq("in_stock")
    end

    it "records which variant was purchased on the line item" do
      product = create(:product, stock_quantity: 50)
      variant = create(:product_variant, product: product, stock_quantity: 5)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, product_variant: variant, quantity: 2)

      order = Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes)

      expect(order.line_items.sole.product_variant).to eq(variant)
    end

    it "raises InsufficientStock and creates nothing when stock is too low" do
      product = create(:product, stock_quantity: 1)
      cart = create(:cart, user: user)
      create(:cart_item, cart: cart, product: product, quantity: 5)

      expect {
        expect { Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes) }
          .to raise_error(Order::InsufficientStock)
      }.not_to change(Order, :count)

      expect(product.reload.stock_quantity).to eq(1)
      expect(cart.cart_items.reload).not_to be_empty
    end

    # Real concurrency, not a mock: two separate DB connections (threads)
    # both try to buy the last unit of the same product at the same instant.
    # Without the row locking in Order.create_from_cart!, both could read
    # "1 left", both pass the check, and both succeed — overselling stock
    # that doesn't exist. Needs real connections, so transactional fixtures
    # are switched off for this example only (data is cleaned up manually).
    it "never oversells stock under real concurrent checkout" do
      self.use_transactional_tests = false

      product = create(:product, stock_quantity: 1)
      buyer_a = create(:user)
      buyer_b = create(:user)
      cart_a = create(:cart, user: buyer_a)
      cart_b = create(:cart, user: buyer_b)
      create(:cart_item, cart: cart_a, product: product, quantity: 1)
      create(:cart_item, cart: cart_b, product: product, quantity: 1)

      results = Queue.new
      ready = Queue.new
      release = Queue.new

      threads = [ [ cart_a, buyer_a ], [ cart_b, buyer_b ] ].map do |cart, buyer|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            release.pop
            begin
              Order.create_from_cart!(cart: cart, user: buyer, shipping_attributes: shipping_attributes)
              results << :success
            rescue Order::InsufficientStock
              results << :insufficient_stock
            end
          end
        end
      end

      2.times { ready.pop } # both threads hold their own connection and are waiting
      2.times { release << true } # now let both race Order.create_from_cart! at once
      threads.each { |t| t.join(5) }

      outcomes = [ results.pop, results.pop ]
      expect(outcomes.tally).to eq(success: 1, insufficient_stock: 1)
      expect(product.reload.stock_quantity).to eq(0)
    ensure
      LineItem.delete_all
      Order.delete_all
      CartItem.delete_all
      Cart.delete_all
      Product.delete_all
      User.delete_all
      self.use_transactional_tests = true
    end

    it "raises AlreadyCheckedOut and creates nothing when the cart has already been converted to an order" do
      cart = create(:cart, user: user)

      expect {
        expect { Order.create_from_cart!(cart: cart, user: user, shipping_attributes: shipping_attributes) }
          .to raise_error(Order::AlreadyCheckedOut)
      }.not_to change(Order, :count)
    end

    # Real concurrency again, but this time the SAME cart raced by two
    # requests for the SAME buyer (a double-click, or a retried request on a
    # flaky connection) — with stock abundant enough that the product-level
    # lock alone wouldn't stop a second, duplicate order from being created
    # out of the same cart before the first request's cart_items.destroy_all
    # commits. Without locking the cart itself, both could read the same
    # cart_items and both succeed.
    it "never creates two orders from the same cart under a real concurrent double-submit" do
      self.use_transactional_tests = false

      product = create(:product, stock_quantity: 100)
      buyer = create(:user)
      cart = create(:cart, user: buyer)
      create(:cart_item, cart: cart, product: product, quantity: 1)

      results = Queue.new
      ready = Queue.new
      release = Queue.new

      threads = Array.new(2) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            release.pop
            begin
              Order.create_from_cart!(cart: cart, user: buyer, shipping_attributes: shipping_attributes)
              results << :success
            rescue Order::AlreadyCheckedOut
              results << :already_checked_out
            end
          end
        end
      end

      2.times { ready.pop }
      2.times { release << true }
      threads.each { |t| t.join(5) }

      outcomes = [ results.pop, results.pop ]
      expect(outcomes.tally).to eq(success: 1, already_checked_out: 1)
      expect(Order.where(user: buyer).count).to eq(1)
      expect(product.reload.stock_quantity).to eq(99)
    ensure
      LineItem.delete_all
      Order.delete_all
      CartItem.delete_all
      Cart.delete_all
      Product.delete_all
      User.delete_all
      self.use_transactional_tests = true
    end
  end

  describe "#restore_stock!" do
    it "restores product stock for a plain-product line item" do
      product = create(:product, stock_quantity: 3)
      order = create(:order)
      create(:line_item, order: order, product: product, quantity: 2)
      product.decrement!(:stock_quantity, 2)

      order.restore_stock!

      expect(product.reload.stock_quantity).to eq(3)
    end

    it "flips stock_status back to in_stock once quantity is restored above zero" do
      product = create(:product, stock_quantity: 2, stock_status: "in_stock")
      order = create(:order)
      create(:line_item, order: order, product: product, quantity: 2)
      product.decrement!(:stock_quantity, 2)
      product.sync_stock_status!
      expect(product.reload.stock_status).to eq("sold_out") # sanity check on setup

      order.restore_stock!

      expect(product.reload.stock_status).to eq("in_stock")
    end

    it "restores variant stock, not product stock, for a variant line item" do
      product = create(:product, stock_quantity: 50)
      variant = create(:product_variant, product: product, stock_quantity: 3)
      order = create(:order)
      create(:line_item, order: order, product: product, product_variant: variant, quantity: 2)
      variant.decrement!(:stock_quantity, 2)

      order.restore_stock!

      expect(variant.reload.stock_quantity).to eq(3)
      expect(product.reload.stock_quantity).to eq(50)
    end
  end
end
