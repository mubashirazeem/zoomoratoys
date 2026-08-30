module Payments
  module Tabby
    # The actual POST /api/v2/checkout call and request body, shared by
    # CreateOrder (brand-new order from a cart) and ResumeOrder (an
    # existing awaiting_payment order whose first attempt was cancelled,
    # failed, or simply abandoned). Neither caller ever reuses a previous
    # web_url/payment_id — Tabby's own testing checklist requires a fresh,
    # disposable session for every payment attempt, so this is always a new
    # POST, never a cache lookup.
    class SessionBuilder
      def self.call(...)
        new(...).call
      end

      def initialize(order:, user:, success_url:, cancel_url:, failure_url:)
        @order = order
        @user = user
        @success_url = success_url
        @cancel_url = cancel_url
        @failure_url = failure_url
      end

      def call
        response = Payments::Tabby.post("/api/v2/checkout", body)

        # A rejected session is a normal business outcome (the customer
        # isn't eligible for this order), not an API failure — Tabby's own
        # testing checklist is explicit that this must never be logged as
        # an error or alert. There's no web_url on a reject, so this is
        # signaled distinctly from the "response was malformed" case below.
        return { rejected: true, message: self.class.rejection_message(response) } if response["status"] == "rejected"

        web_url = response.dig("configuration", "available_products", "installments", 0, "web_url")
        payment_id = response.dig("payment", "id")

        if web_url.blank? || payment_id.blank?
          raise Payments::ProviderError, "Tabby checkout session response had no web_url/payment id: #{response.inspect}"
        end

        { web_url: web_url, payment_id: payment_id }
      end

      # Shared with Payments::Tabby::CheckEligibility, which hits this same
      # endpoint with a minimal payload purely to pre-score a customer
      # before Place Order — same response shape, same rejection_reason
      # values, so the same copy applies either way.
      REJECTION_MESSAGES = {
        "order_amount_too_high" => "This order total is too high for Tabby — please choose a different payment method.",
        "order_amount_too_low" => "This order total is too low for Tabby — please choose a different payment method.",
        "not_available" => "Tabby isn't available for this order right now."
      }.freeze

      def self.rejection_message(response)
        installments = response.dig("configuration", "products", "installments")
        # Documented as a single object, not an array like
        # available_products.installments — handled explicitly rather than
        # via Array(), whose Hash#to_a behavior would silently mangle a
        # Hash into [key, value] pairs instead of wrapping it.
        products = case installments
        when Array then installments
        when Hash then [ installments ]
        else []
        end
        reason = (products.find { |p| p["is_available"] == false } || products.first)&.dig("rejection_reason")
        REJECTION_MESSAGES.fetch(reason, REJECTION_MESSAGES["not_available"])
      end

      private

      def body
        {
          payment: {
            amount: format("%.2f", @order.total_cents / 100.0),
            currency: "AED",
            buyer: { name: @user.full_name, email: @user.email, phone: @order.shipping_phone },
            buyer_history: { registered_since: @user.created_at.iso8601, loyalty_level: 0 },
            order: {
              reference_id: @order.order_number,
              items: @order.line_items.includes(:product).map { |li| line_item_payload(li) }
            },
            shipping_address: { city: @order.shipping_city, address: @order.shipping_address_line1, zip: "00000" },
            order_history: order_history_for(@order)
          },
          lang: "en",
          merchant_code: ENV.fetch("TABBY_MERCHANT_CODE"),
          merchant_urls: { success: @success_url, cancel: with_recovery_param(@cancel_url), failure: with_recovery_param(@failure_url) }
        }
      end

      # Tags the cancel/failure URLs with this order's number, so
      # CheckoutsController#show can tell a genuine bounce-back from
      # Tabby's own hosted page (customer cancelled or the attempt failed)
      # apart from an ordinary visit to /checkout — see
      # CheckoutsController#recover_from_incomplete_tabby_payment. That's
      # what lets it safely release this exact order's stock reservation
      # and hand the cart back, per "cart is kept after cancellation/
      # failure, cleared after a successful payment."
      def with_recovery_param(url)
        uri = URI.parse(url)
        params = URI.decode_www_form(uri.query.to_s)
        params << [ "tabby_recover", @order.order_number ]
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      # Tabby's spec: "5-10 previously placed via any payment method orders
      # in any status, current order excluded." awaiting_payment is
      # excluded too — a still-mid-checkout order was never actually
      # placed, and might never complete. Empty array (a first-time
      # customer) is explicitly fine per the same docs.
      def order_history_for(order)
        @user.orders.where.not(id: order.id).where.not(status: "awaiting_payment")
          .order(placed_at: :desc).limit(10).map do |past_order|
          {
            purchased_at: past_order.placed_at.iso8601,
            amount: format("%.2f", past_order.total_cents / 100.0),
            status: tabby_status_for(past_order.status),
            buyer: { name: past_order.shipping_name, email: @user.email, phone: past_order.shipping_phone },
            shipping_address: { city: past_order.shipping_city, address: past_order.shipping_address_line1, zip: "00000" }
          }
        end
      end

      # Our enum -> Tabby's documented order_history status enum ("new",
      # "processing", "complete", "refunded", "canceled", "unknown").
      TABBY_ORDER_HISTORY_STATUS = {
        "pending" => "new", "processing" => "processing", "shipped" => "complete",
        "delivered" => "complete", "cancelled" => "canceled", "refunded" => "refunded"
      }.freeze

      def tabby_status_for(status)
        TABBY_ORDER_HISTORY_STATUS.fetch(status, "unknown")
      end

      def line_item_payload(line_item)
        {
          title: line_item.product.name,
          quantity: line_item.quantity,
          unit_price: format("%.2f", line_item.price_cents / 100.0),
          reference_id: line_item.product_id.to_s,
          category: line_item.product.category&.name || "General"
        }
      end
    end
  end
end
