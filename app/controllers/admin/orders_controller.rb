# frozen_string_literal: true

# No create/destroy here — orders come from checkout (once built), never
# created or deleted from the admin panel. Only status can be changed.
class Admin::OrdersController < Admin::BaseController
  # Contact details shown on the printed invoice/packing slip specifically
  # (client-provided, 2026-07-18) — distinct from the general storefront
  # contact info in Layout::SiteFooterComponent.
  INVOICE_ACCOUNTS_EMAIL = "accounts@zoomora.com"
  INVOICE_SALES_EMAIL = "sales@zoomora.com"
  INVOICE_MOBILE = "+971 52 722 5064"

  before_action :set_order, only: [ :show, :update, :packing_slip, :invoice, :refund ]

  def index
    @orders = Order.includes(:user).newest_first
    @orders = @orders.where(status: params[:status]) if params[:status].present?
    @orders = @orders.search(params[:q]) if params[:q].present?
    @orders = @orders.page(params[:page]).per(24)
  end

  def show
    @line_items = @order.line_items.includes(:product)
  end

  def update
    status = order_params[:status]

    unless Order::MANUALLY_SETTABLE_STATUSES.include?(@order.status)
      redirect_to admin_order_path(@order), alert: "This order's status is managed automatically and can't be changed here."
      return
    end

    unless Order::MANUALLY_SETTABLE_STATUSES.include?(status)
      redirect_to admin_order_path(@order), alert: "\"#{status}\" can't be set from the admin panel — it's managed automatically."
      return
    end

    # Newly-cancelling (not already cancelled — a resubmitted form must not
    # restore twice) and not yet shipped is the same "units never left the
    # warehouse" condition Payments::RefundIssuer restores stock on. Without
    # this, cancelling a paid-but-unshipped order here left its stock
    # decremented forever — cancelling and refunding are two separate admin
    # actions (see the payment-status warning on this page), but stock
    # accuracy shouldn't depend on the admin remembering to also hit Refund.
    should_restore_stock = status == "cancelled" && !@order.cancelled? && @order.stock_restorable?

    if @order.update(status: status)
      @order.restore_stock! if should_restore_stock
      redirect_to admin_order_path(@order), notice: "Order status updated to #{@order.status.humanize}."
    else
      redirect_to admin_order_path(@order), alert: @order.errors.full_messages.to_sentence
    end
  end

  # Print-ready delivery note — shipping details and line items only, no
  # prices, matching the standard warehouse/packing-slip convention (this
  # document travels with the shipment, it isn't a financial record).
  def packing_slip
    @line_items = @order.line_items.includes(:product)
    render layout: "print"
  end

  # Print-ready invoice — the financial record: prices, totals, payment
  # method, billed to the customer's account.
  def invoice
    @line_items = @order.line_items.includes(:product)
    render layout: "print"
  end

  # Full refund only. Re-checks refundable? here rather than trusting the
  # view to have hidden the button — this handles real money, so the guard
  # has to hold even if this action is hit directly (stale page, replayed
  # request, curl, etc).
  def refund
    unless @order.refundable?
      redirect_to admin_order_path(@order), alert: "This order can't be refunded."
      return
    end

    Payments::RefundIssuer.call(order: @order)
    redirect_to admin_order_path(@order), notice: "Order refunded."
  rescue Stripe::StripeError => e
    redirect_to admin_order_path(@order), alert: "Refund failed: #{e.message}"
  end

  private

  def set_order
    @order = Order.includes(:user).find(params[:id])
  end

  def order_params
    params.require(:order).permit(:status)
  end
end
