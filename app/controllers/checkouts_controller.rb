# frozen_string_literal: true

# Real checkout — requires sign-in (Order#user is required, and Order
# History already only makes sense for a real account; see
# ApplicationController's guest-cart-merges-on-sign-in flow, which means a
# guest who reaches here and signs in keeps everything they'd added).
#
# Payment method: Pay on Delivery (unchanged, synchronous) or Stripe Card
# (redirects to a Stripe-hosted Checkout Session; the order stays
# awaiting_payment until Payments::WebhookHandler confirms or expires it —
# see Order's payment_method/status enums).
class CheckoutsController < ApplicationController
  before_action :authenticate_user!
  before_action -> { @robots_noindex = true }
  before_action :ensure_cart_has_items, only: [ :show, :create ]
  before_action :ensure_cart_is_purchasable, only: [ :show, :create ]

  def show
    @gift_wrap_cents = CartsController::GIFT_WRAP_CENTS
    @express_delivery_cents = CartsController::EXPRESS_DELIVERY_CENTS
    @addresses = current_user.addresses.ordered
  end

  def create
    if params[:payment_method] == "card"
      # Named stripe_checkout_url, not checkout_url — this method is inside
      # a controller where `checkout_url` is already the Rails route helper
      # for /checkout (singular `resource :checkout`). Assigning a local
      # variable of that same name would shadow the helper for the rest of
      # this method, including inside this very call's own `cancel_url:`
      # argument (Ruby resolves a bare identifier to a local variable the
      # moment the parser has seen an assignment to that name anywhere
      # earlier in the same statement, even though it hasn't run yet) —
      # silently passing `nil` instead of "/checkout".
      stripe_checkout_url = Payments::CreateCardOrder.call(
        cart: current_cart, user: current_user, shipping_attributes: shipping_attributes,
        gift_wrap: params[:gift_wrap].present?, gift_wrap_cents: CartsController::GIFT_WRAP_CENTS,
        gift_wrap_name: params[:gift_wrap_name], delivery_method: selected_delivery_method,
        delivery_fee_cents: CartsController::EXPRESS_DELIVERY_CENTS,
        success_url_for: ->(order) { checkout_confirmation_url(order.order_number) },
        cancel_url: checkout_url
      )
      save_address_for_next_time if params[:save_address].present?
      redirect_to stripe_checkout_url, allow_other_host: true
    else
      order = Order.create_from_cart!(
        cart: current_cart,
        user: current_user,
        shipping_attributes: shipping_attributes,
        gift_wrap: params[:gift_wrap].present?,
        gift_wrap_cents: CartsController::GIFT_WRAP_CENTS,
        gift_wrap_name: params[:gift_wrap_name],
        delivery_method: selected_delivery_method,
        delivery_fee_cents: CartsController::EXPRESS_DELIVERY_CENTS
      )
      save_address_for_next_time if params[:save_address].present?
      # Card orders are confirmed by mail once Payments::WebhookHandler
      # hears back from Stripe (see that class) — a Pay on Delivery order
      # is fully placed the moment this line runs, so it's confirmed here.
      OrderMailer.confirmation(order).deliver_later
      AdminMailer.new_order(order).deliver_later
      redirect_to checkout_confirmation_path(order.order_number)
    end
  rescue Order::InsufficientStock => e
    redirect_to cart_path, alert: e.message
  rescue Order::AlreadyCheckedOut
    redirect_to cart_path, alert: "It looks like this order was already placed — check your order history before trying again."
  rescue ActiveRecord::RecordInvalid => e
    @gift_wrap_cents = CartsController::GIFT_WRAP_CENTS
    @express_delivery_cents = CartsController::EXPRESS_DELIVERY_CENTS
    @addresses = current_user.addresses.ordered
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_content
  rescue Stripe::StripeError => e
    Rails.logger.error("Checkout: Stripe error creating session for user #{current_user.id}: #{e.message}")
    redirect_to cart_path, alert: "We couldn't start your card payment. Please try again."
  end

  def confirmation
    @order = current_user.orders.includes(line_items: :product).find_by!(order_number: params[:order_number])
  end

  private

  # Runs before both show and create — an empty cart has nothing to check
  # out, whether someone lands here directly or their cart emptied out from
  # another tab in between.
  def ensure_cart_has_items
    redirect_to cart_path, alert: "Your cart is empty." if current_cart.cart_items.none?
  end

  # Catches a stock shortfall (something sold out, or someone else bought
  # the last unit) before the customer fills out the whole shipping form,
  # not just at the very last moment. This is a courtesy check, not the
  # real enforcement — Order.create_from_cart!'s row-locked check is what
  # actually prevents overselling; #create's own rescue Order::
  # InsufficientStock stays in place as the final word for the (rare) case
  # where stock changes in the moment between this check and that one.
  def ensure_cart_is_purchasable
    return unless current_cart.cart_items.any?(&:stock_shortfall?)

    redirect_to cart_path, alert: "Something in your cart is no longer available in that quantity — please update your cart before checking out."
  end

  # Only "express" is ever opted into from the form (a radio button) —
  # anything else, including a tampered or missing param, falls back to the
  # always-free "standard" delivery rather than raising, so a malformed
  # request never lands on the Order model's stricter validation instead.
  def selected_delivery_method
    params[:delivery_method] == "express" ? "express" : "standard"
  end

  def shipping_attributes
    params.permit(
      :shipping_name, :shipping_phone, :shipping_address_line1,
      :shipping_address_line2, :shipping_city, :shipping_emirate
    ).to_h.symbolize_keys
  end

  # "Save this address for next time" — skips creating a near-duplicate if
  # the exact same address is already saved.
  #
  # Runs *after* the order already exists — a failure here must never look
  # like a failed checkout. It's rescued locally rather than letting
  # ActiveRecord::RecordInvalid bubble up into #create's own rescue (meant
  # for a genuinely failed order), which would otherwise re-render the
  # checkout page with an error even though the customer's order already
  # went through — logged so a real bug here doesn't go unnoticed, since
  # there's no error-tracking service to catch it another way yet.
  def save_address_for_next_time
    attrs = shipping_attributes
    already_saved = current_user.addresses.exists?(
      full_name: attrs[:shipping_name], phone: attrs[:shipping_phone],
      address_line1: attrs[:shipping_address_line1], city: attrs[:shipping_city],
      emirate: attrs[:shipping_emirate]
    )
    return if already_saved

    is_first_address = current_user.addresses.none?
    current_user.addresses.create!(
      full_name: attrs[:shipping_name], phone: attrs[:shipping_phone],
      address_line1: attrs[:shipping_address_line1], address_line2: attrs[:shipping_address_line2],
      city: attrs[:shipping_city], emirate: attrs[:shipping_emirate],
      default_address: is_first_address
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Checkout: failed to save address for user #{current_user.id}: #{e.record.errors.full_messages.to_sentence}")
  end
end
