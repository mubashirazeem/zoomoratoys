module Payments
  module Tamara
    # Same money-safety shape as Payments::CreateCardOrder and
    # Payments::Tabby::CreateOrder — Order.create_from_cart! (row-locked
    # stock check) and the provider API call happen inside one DB
    # transaction, so a failed Tamara call rolls the stock reservation back
    # too.
    #
    # Not considered paid here — created as awaiting_payment, same as card
    # and Tabby, and only flipped by Tamara's own webhook
    # (Payments::Tamara::WebhookHandler) once it reports "approved".
    class CreateOrder
      def self.call(...)
        new(...).call
      end

      def initialize(cart:, user:, shipping_attributes:, success_url_for:, cancel_url:, failure_url:, notification_url:,
                     gift_wrap: false, gift_wrap_cents: 0, gift_wrap_name: nil, delivery_method: "standard", delivery_fee_cents: 0)
        @cart = cart
        @user = user
        @shipping_attributes = shipping_attributes
        @success_url_for = success_url_for
        @cancel_url = cancel_url
        @failure_url = failure_url
        @notification_url = notification_url
        @gift_wrap = gift_wrap
        @gift_wrap_cents = gift_wrap_cents
        @gift_wrap_name = gift_wrap_name
        @delivery_method = delivery_method
        @delivery_fee_cents = delivery_fee_cents
      end

      def call
        checkout_url = nil

        ActiveRecord::Base.transaction do
          order = Order.create_from_cart!(
            cart: @cart, user: @user, shipping_attributes: @shipping_attributes,
            gift_wrap: @gift_wrap, gift_wrap_cents: @gift_wrap_cents, gift_wrap_name: @gift_wrap_name,
            delivery_method: @delivery_method, delivery_fee_cents: @delivery_fee_cents,
            payment_method: "tamara"
          )

          response = create_session(order)
          url = response["checkout_url"]
          order_id = response["order_id"]

          if url.blank? || order_id.blank?
            raise Payments::ProviderError, "Tamara checkout session response had no checkout_url/order_id: #{response.inspect}"
          end

          order.update!(tamara_order_id: order_id)
          checkout_url = url
        end

        checkout_url
      end

      private

      def create_session(order)
        amount = format("%.2f", order.total_cents / 100.0)
        first_name, *rest = @user.full_name.split(" ")
        last_name = rest.join(" ").presence || first_name

        body = {
          order_reference_id: order.order_number,
          total_amount: { amount: amount, currency: "AED" },
          # Both required top-level fields — Tamara's own validation only
          # returns a clean 4xx (e.g. "empty_shipping_amount") when exactly
          # one is missing; omitting *both* at once (as this used to)
          # crashes their backend into a generic, undiagnosable
          # "Something went wrong with us" 500 instead. Confirmed by
          # isolating each field individually against the real sandbox.
          shipping_amount: { amount: format("%.2f", order.delivery_fee_cents / 100.0), currency: "AED" },
          tax_amount: { amount: format("%.2f", order.vat_cents / 100.0), currency: "AED" },
          description: "Zoomora order #{order.order_number}",
          country_code: "AE",
          items: order.line_items.includes(:product).map { |li| line_item_payload(li) },
          consumer: { first_name: first_name, last_name: last_name, phone_number: order.shipping_phone, email: @user.email },
          shipping_address: {
            first_name: first_name, last_name: last_name, line1: order.shipping_address_line1,
            city: order.shipping_city, country_code: "AE"
          },
          merchant_url: {
            success: @success_url_for.call(order),
            failure: with_recovery_param(@failure_url, order, "failed"),
            cancel: with_recovery_param(@cancel_url, order, "cancelled"),
            notification: @notification_url
          }
        }

        Payments::Tamara.post("/checkout", body)
      end

      # Same reasoning as Payments::Tabby::SessionBuilder#with_recovery_param
      # — tags the cancel/failure URLs with this order's number and outcome
      # so CheckoutsController#recover_from_incomplete_tamara_payment can
      # tell a genuine bounce-back from Tamara's own hosted page apart from
      # an ordinary visit to /checkout, and show the right message for each.
      def with_recovery_param(url, order, outcome)
        uri = URI.parse(url)
        params = URI.decode_www_form(uri.query.to_s)
        params << [ "tamara_recover", order.order_number ]
        params << [ "tamara_outcome", outcome ]
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      def line_item_payload(line_item)
        {
          reference_id: line_item.product_id.to_s,
          type: "Physical_product",
          name: line_item.product.name,
          sku: line_item.product.sku,
          quantity: line_item.quantity,
          total_amount: { amount: format("%.2f", line_item.price_cents * line_item.quantity / 100.0), currency: "AED" }
        }
      end
    end
  end
end
