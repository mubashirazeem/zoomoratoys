# frozen_string_literal: true

# Real query against the `orders` table (see Order model), written by
# CheckoutsController at the end of a real checkout.
class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action -> { @robots_noindex = true }

  def index
    @orders = current_user.orders.newest_first
  end

  # Scoped to current_user, same as index — a customer can only ever look
  # up their own orders, never someone else's by guessing an id.
  def show
    @order = current_user.orders.includes(line_items: { product: { images_attachments: :blob } }).find(params[:id])
  end

  # Lets a customer restart payment for a card order they never completed
  # (closed the Stripe tab, hit back, etc.) — see Payments::ResumeCardOrder.
  # Only ever valid pre-payment; once paid (or once the original session
  # expires and Payments::WebhookHandler cancels it) this order is no
  # longer awaiting_payment and this action has nothing left to do.
  def resume_payment
    order = current_user.orders.find(params[:id])

    unless order.card? && order.awaiting_payment?
      return redirect_to order_path(order), alert: "This order can't be resumed."
    end

    checkout_url = Payments::ResumeCardOrder.call(
      order: order, user: current_user,
      success_url_for: ->(o) { checkout_confirmation_url(o.order_number) },
      cancel_url: order_url(order)
    )
    redirect_to checkout_url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("Resume payment: Stripe error for order #{order.id}: #{e.message}")
    redirect_to order_path(order), alert: "We couldn't restart your card payment. Please try again."
  end
end
