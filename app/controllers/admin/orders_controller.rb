# frozen_string_literal: true

# No destroy here — orders are never deleted, only cancelled (a real,
# auditable status). Create exists for manual/phone/WhatsApp sales that
# never went through the real storefront checkout; see Order.create_by_admin!.
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

  def new
    @sku_options = sku_options
  end

  # No cart involved — items come straight from the form as a
  # {product_id, product_variant_id, quantity} list. See
  # Order.create_by_admin! for the stock-locking/decrement logic itself.
  def create
    user = User.find_by(email: order_params[:user_email].to_s.strip.downcase)
    unless user
      return render_new_with_error("No customer found with that email — create the customer first, then try again.")
    end

    items = parse_items(order_params[:items])
    return render_new_with_error("Add at least one product with a quantity.") if items.empty?

    order = Order.create_by_admin!(
      user: user, items: items, shipping_attributes: shipping_attributes,
      gift_wrap: order_params[:gift_wrap].present?, gift_wrap_cents: CartsController::GIFT_WRAP_CENTS
    )
    # No AdminMailer.new_order here — the admin placing this order already
    # knows about it; only the customer needs a receipt.
    OrderMailer.confirmation(order).deliver_later
    redirect_to admin_order_path(order), notice: "Order #{order.order_number} created."
  rescue Order::InsufficientStock => e
    render_new_with_error(e.message)
  rescue ActiveRecord::RecordInvalid => e
    render_new_with_error(e.record.errors.full_messages.to_sentence)
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
    newly_shipped = status == "shipped" && !@order.shipped?
    newly_cancelled = status == "cancelled" && !@order.cancelled?

    if @order.update(status: status)
      @order.restore_stock! if should_restore_stock
      OrderMailer.shipped(@order).deliver_later if newly_shipped
      OrderMailer.cancelled(@order).deliver_later if newly_cancelled
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
    params.require(:order).permit(
      :status, :user_email, :shipping_name, :shipping_phone, :shipping_address_line1,
      :shipping_address_line2, :shipping_city, :shipping_emirate, :gift_wrap,
      items: [ :sku, :quantity ]
    )
  end

  def shipping_attributes
    order_params.slice(:shipping_name, :shipping_phone, :shipping_address_line1, :shipping_address_line2, :shipping_city, :shipping_emirate).to_h.symbolize_keys
  end

  # Flattens the catalog into one option per orderable thing — a plain
  # product, or one option per variant for a product that has them (stock
  # is tracked per-variant once a product has any, see Product#has_variants?,
  # so a variant-having product can never be ordered "plain"). Encodes both
  # ids into a single value (`product_id` or `product_id:variant_id`) so the
  # form needs only one flat <select> per line, no cascading product ->
  # variant JS.
  def sku_options
    Product.includes(:product_variants).order(:name).flat_map do |product|
      if product.has_variants?
        product.product_variants.map { |variant| [ "#{product.name} — #{variant.option_summary}", "#{product.id}:#{variant.id}" ] }
      else
        [ [ product.name, product.id.to_s ] ]
      end
    end
  end

  # Blank rows (an admin leaving unused item slots empty) and zero-quantity
  # rows are silently skipped rather than erroring — the form always renders
  # a fixed, generous number of slots (see admin/orders/new.html.erb) so
  # "leave the rest blank" is the expected, normal way to submit fewer items.
  def parse_items(raw_items)
    return [] if raw_items.blank?

    # Indexed keys (order[items][0][sku], from the fixed-row-count form)
    # arrive as a Hash keyed "0", "1", ... — never an Array — unlike the
    # empty-bracket order[items][][sku] convention, which Rack does parse
    # as an Array. #values here normalizes either shape to a plain list.
    raw_items.values.filter_map do |row|
      sku = row[:sku].to_s
      quantity = row[:quantity].to_i
      next if sku.blank? || quantity <= 0

      product_id, variant_id = sku.split(":")
      product = Product.find(product_id)
      variant = variant_id.present? ? product.product_variants.find(variant_id) : nil
      { product: product, product_variant: variant, quantity: quantity }
    end
  end

  def render_new_with_error(message)
    @sku_options = sku_options
    flash.now[:alert] = message
    render :new, status: :unprocessable_content
  end
end
