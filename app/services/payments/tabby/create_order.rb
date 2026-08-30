module Payments
  module Tabby
    # Creates an Order the exact same money-safe way Payments::CreateCardOrder
    # does for Stripe — same row-locked stock check inside Order.create_from_cart!,
    # same "if the provider call fails, roll the stock reservation back too"
    # guarantee from doing both inside one DB transaction. The only real
    # difference from Stripe is the API call itself: one POST that returns a
    # URL to redirect the customer to, instead of a full session object.
    #
    # The order is NOT considered paid here — it's created as
    # awaiting_payment, same as a card order, and only Tabby's own webhook
    # (Payments::Tabby::WebhookHandler) ever flips it to paid. Tabby's own
    # docs are explicit that the browser redirect back to the success URL is
    # not proof of payment.
    class CreateOrder
      def self.call(...)
        new(...).call
      end

      def initialize(cart:, user:, shipping_attributes:, success_url_for:, cancel_url:, failure_url:,
                     gift_wrap: false, gift_wrap_cents: 0, gift_wrap_name: nil, delivery_method: "standard", delivery_fee_cents: 0)
        @cart = cart
        @user = user
        @shipping_attributes = shipping_attributes
        @success_url_for = success_url_for
        @cancel_url = cancel_url
        @failure_url = failure_url
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
            payment_method: "tabby"
          )

          session = SessionBuilder.call(
            order: order, user: @user,
            success_url: @success_url_for.call(order), cancel_url: @cancel_url, failure_url: @failure_url
          )

          # A reject here rolls this entire transaction back — no order
          # ever gets committed, no stock ever gets decremented, and the
          # cart is untouched, exactly as if this attempt never happened.
          # There's no web_url to redirect to on a reject, so this is
          # deliberately a distinct exception from Payments::ProviderError:
          # CheckoutsController#create must show session[:message] on the
          # checkout page itself, not log/alert or bounce to another host.
          raise Payments::SessionRejected, session[:message] if session[:rejected]

          order.update!(tabby_payment_id: session[:payment_id])
          checkout_url = session[:web_url]
        end

        checkout_url
      end
    end
  end
end
