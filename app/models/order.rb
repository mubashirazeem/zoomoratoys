# frozen_string_literal: true

# Real schema, and — as of Checkout landing — a real writer: Order.
# create_from_cart! is the one place an Order gets created. Order History
# (OrdersController#index) queries this the same way it always has.
class Order < ApplicationRecord
  has_paper_trail

  class InsufficientStock < StandardError; end
  class AlreadyCheckedOut < StandardError; end

  EMIRATES = [
    "Abu Dhabi", "Dubai", "Sharjah", "Ajman",
    "Umm Al Quwain", "Ras Al Khaimah", "Fujairah"
  ].freeze

  belongs_to :user
  belongs_to :coupon, optional: true
  has_many :line_items, dependent: :destroy

  enum :status, { awaiting_payment: "awaiting_payment", pending: "pending", processing: "processing",
                   shipped: "shipped", delivered: "delivered", cancelled: "cancelled", refunded: "refunded" },
       default: "pending", validate: true
  # Only two payment methods exist — Pay on Delivery and real Stripe card
  # payments (Milestone 4, see PROJECT_VISION.md).
  enum :payment_method, { pay_on_delivery: "pay_on_delivery", card: "card" },
       default: "pay_on_delivery", validate: true

  # awaiting_payment is only ever set by Order.create_from_cart! for a card
  # order, and only ever left by the Stripe webhook (Payments::WebhookHandler)
  # confirming or expiring the payment. refunded is only ever set by
  # Payments::RefundIssuer or a webhook-confirmed Stripe refund. Neither
  # should be a choice in the admin panel's manual status dropdown — see
  # app/views/admin/orders/show.html.erb.
  MANUALLY_SETTABLE_STATUSES = statuses.keys - %w[awaiting_payment refunded]

  # Single source of truth for the admin badge color of every status — the
  # index and customer-detail pages both render this, and used to each keep
  # their own hardcoded copy of this mapping. That duplication is exactly
  # why awaiting_payment/refunded landed in one view but not the other and
  # crashed with KeyError: adding a status here now fixes every caller at
  # once, and #fetch's default means a future status that's never added here
  # degrades to a plain neutral badge instead of crashing the page.
  ADMIN_STATUS_TONES = {
    "awaiting_payment" => :attention,
    "pending" => :neutral,
    "processing" => :neutral,
    "shipped" => :positive,
    "delivered" => :positive,
    "cancelled" => :negative,
    "refunded" => :negative
  }.freeze

  def admin_status_tone
    ADMIN_STATUS_TONES.fetch(status, :neutral)
  end

  # Customer-facing status badge classes — was duplicated verbatim across
  # orders/index.html.erb and orders/show.html.erb (the exact drift risk
  # ADMIN_STATUS_TONES above was introduced to avoid, just not extended to
  # this side).
  CUSTOMER_STATUS_CLASSES = {
    "awaiting_payment" => "bg-grey-100 text-grey-500",
    "pending" => "bg-grey-100 text-grey-700",
    "processing" => "bg-grey-200 text-ink-950",
    "shipped" => "bg-red-600/10 text-red-600",
    "delivered" => "bg-ink-950 text-white",
    "cancelled" => "bg-grey-100 text-grey-400",
    "refunded" => "bg-red-600/10 text-red-600"
  }.freeze

  def customer_status_classes
    CUSTOMER_STATUS_CLASSES.fetch(status, "bg-grey-100 text-grey-700")
  end

  validates :order_number, presence: true, uniqueness: true
  validates :total_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :subtotal_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gift_wrap_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gift_wrap_name, length: { maximum: 100 }
  validates :delivery_method, presence: true, inclusion: { in: %w[standard express] }
  validates :delivery_fee_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :discount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :placed_at, presence: true
  validates :shipping_name, :shipping_address_line1, :shipping_city, presence: true, length: { maximum: 150 }
  validates :shipping_phone, presence: true, length: { maximum: 30 }
  validates :shipping_address_line2, length: { maximum: 150 }
  validates :shipping_emirate, presence: true, inclusion: { in: EMIRATES }

  scope :newest_first, -> { order(placed_at: :desc) }

  # Admin order search — order number or the customer's name/email. Same
  # bound-parameter, %/_-escaped pattern as Product.search.
  scope :search, ->(query) {
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    joins(:user).where(
      "orders.order_number ILIKE :pattern OR users.first_name ILIKE :pattern OR users.last_name ILIKE :pattern OR users.email ILIKE :pattern",
      pattern: pattern
    )
  }

  # The one place an Order gets created — from a real Cart at checkout.
  #
  # Concurrency-safe by design, not just by hope: every Product/ProductVariant
  # row involved is locked (`SELECT ... FOR UPDATE`) in a stable ascending-id
  # order *before* any stock is checked. Without this, two customers
  # checking out the last unit of the same product at the same instant could
  # both read "1 left", both pass the check, and both succeed — overselling
  # stock that doesn't exist. The stable lock order also prevents a deadlock
  # between two concurrent checkouts that share more than one product but
  # would otherwise lock them in opposite orders.
  #
  # cart.lock! guards a separate race: a double-click or a retried request
  # on a flaky connection submitting checkout twice for the *same* cart.
  # When stock is abundant, the product-level locking above doesn't stop a
  # second, duplicate order from being created out of the same cart_items —
  # it only stops overselling, not double-ordering. Locking the cart itself
  # forces a concurrent second attempt to wait until the first commits (and
  # destroys cart_items), then re-read cart_items fresh via a direct query
  # (not the cart's possibly-already-loaded association) and find it empty.
  def self.create_from_cart!(cart:, user:, shipping_attributes:, gift_wrap: false, gift_wrap_cents: 0, gift_wrap_name: nil, delivery_method: "standard", delivery_fee_cents: 0, payment_method: "pay_on_delivery", discount_cents: 0, coupon: nil)
    transaction do
      cart.lock!
      items = CartItem.where(cart_id: cart.id).includes(:product, :product_variant).to_a
      raise AlreadyCheckedOut if items.empty?

      locked_variants = {}
      locked_products = {}

      items.sort_by { |item| [ item.product_id, item.product_variant_id || 0 ] }.each do |item|
        if item.product_variant_id
          locked_variants[item.product_variant_id] ||= ProductVariant.lock.find(item.product_variant_id)
        else
          locked_products[item.product_id] ||= Product.lock.find(item.product_id)
        end
      end

      items.each do |item|
        record = item.product_variant_id ? locked_variants[item.product_variant_id] : locked_products[item.product_id]
        if record.stock_quantity < item.quantity
          raise InsufficientStock, "Only #{record.stock_quantity} of #{item.product.name} left in stock"
        end
      end

      applied_gift_wrap_cents = gift_wrap ? gift_wrap_cents : 0
      applied_gift_wrap_name = gift_wrap ? gift_wrap_name.presence : nil
      applied_delivery_fee_cents = delivery_method == "express" ? delivery_fee_cents : 0
      order = create!(
        user: user,
        order_number: generate_order_number,
        placed_at: Time.current,
        subtotal_cents: cart.total_cents,
        gift_wrap_cents: applied_gift_wrap_cents,
        gift_wrap_name: applied_gift_wrap_name,
        delivery_method: delivery_method,
        delivery_fee_cents: applied_delivery_fee_cents,
        discount_cents: discount_cents,
        total_cents: cart.total_cents + applied_gift_wrap_cents + applied_delivery_fee_cents - discount_cents,
        payment_method: payment_method,
        status: payment_method == "card" ? "awaiting_payment" : "pending",
        coupon: coupon,
        **shipping_attributes
      )

      items.each do |item|
        order.line_items.create!(
          product: item.product,
          product_variant: item.product_variant,
          quantity: item.quantity,
          price_cents: item.unit_price_cents
        )
        record = item.product_variant_id ? locked_variants[item.product_variant_id] : locked_products[item.product_id]
        record.decrement!(:stock_quantity, item.quantity)
        record.sync_stock_status!
      end

      cart.cart_items.destroy_all
      order
    end
  end

  # A manual, admin-entered order — no cart, no Stripe (e.g. a phone or
  # WhatsApp sale). `items` is an array of { product:, product_variant:,
  # quantity: } hashes. Deliberately not built by sharing code with
  # .create_from_cart! above: that method is the real, high-stakes,
  # already-proven checkout path, and this is a much lower-traffic,
  # lower-stakes one — duplicating its concurrency-safe locking pattern
  # here (same stable ascending-id lock order, same lock-then-check-then-
  # decrement sequence, for the same overselling/deadlock reasons) avoids
  # any risk of touching that proven path while building this new one.
  def self.create_by_admin!(user:, items:, shipping_attributes:, gift_wrap: false, gift_wrap_cents: 0)
    transaction do
      raise ArgumentError, "at least one item is required" if items.empty?

      locked_variants = {}
      locked_products = {}

      items.sort_by { |item| [ item[:product].id, item[:product_variant]&.id || 0 ] }.each do |item|
        if item[:product_variant]
          locked_variants[item[:product_variant].id] ||= ProductVariant.lock.find(item[:product_variant].id)
        else
          locked_products[item[:product].id] ||= Product.lock.find(item[:product].id)
        end
      end

      items.each do |item|
        record = item[:product_variant] ? locked_variants[item[:product_variant].id] : locked_products[item[:product].id]
        if record.stock_quantity < item[:quantity]
          raise InsufficientStock, "Only #{record.stock_quantity} of #{item[:product].name} left in stock"
        end
      end

      unit_price_cents_for = ->(item) { item[:product_variant]&.effective_price_cents || item[:product].price_cents }
      subtotal_cents = items.sum { |item| unit_price_cents_for.call(item) * item[:quantity] }
      applied_gift_wrap_cents = gift_wrap ? gift_wrap_cents : 0

      order = create!(
        user: user,
        order_number: generate_order_number,
        placed_at: Time.current,
        subtotal_cents: subtotal_cents,
        gift_wrap_cents: applied_gift_wrap_cents,
        discount_cents: 0,
        total_cents: subtotal_cents + applied_gift_wrap_cents,
        payment_method: "pay_on_delivery",
        status: "pending",
        **shipping_attributes
      )

      items.each do |item|
        order.line_items.create!(
          product: item[:product],
          product_variant: item[:product_variant],
          quantity: item[:quantity],
          price_cents: unit_price_cents_for.call(item)
        )
        record = item[:product_variant] ? locked_variants[item[:product_variant].id] : locked_products[item[:product].id]
        record.decrement!(:stock_quantity, item[:quantity])
        record.sync_stock_status!
      end

      order
    end
  end

  # Sequential and human-readable (ZMR-1000, ZMR-1001, ...) per client
  # request — this is also the invoice number shown on the printed invoice,
  # so the two always match by construction (one field, no separate
  # invoice_number column). Concurrency-safe the same way stock is: locks
  # the single counter row with SELECT ... FOR UPDATE inside the enclosing
  # create_from_cart! transaction, so two simultaneous checkouts can never
  # be handed the same number.
  def self.generate_order_number
    counter = OrderNumberCounter.lock.first || OrderNumberCounter.create!(next_value: 1000)
    number = counter.next_value
    counter.increment!(:next_value)
    "ZMR-#{number}"
  end

  # Prices shown throughout the storefront are VAT-inclusive (standard UAE
  # retail display convention) — the customer's charged total never
  # changes for invoicing purposes. These back the 5% VAT amount out of
  # that total for the printed invoice's breakdown.
  VAT_RATE = 0.05

  # Shared by both #vat_cents below (this order's own total) and
  # ApplicationHelper#vat_inclusive_note (any total_cents figure shown on
  # screen, e.g. the cart page before an Order even exists) — was
  # implemented twice with the same arithmetic, independently.
  def self.vat_portion_of(total_cents)
    total_cents - (total_cents / (1 + VAT_RATE)).round
  end

  def amount_excluding_vat_cents
    total_cents - vat_cents
  end

  def vat_cents
    self.class.vat_portion_of(total_cents)
  end

  # The inverse of the stock decrement in .create_from_cart! — used when a
  # Stripe Checkout Session expires without ever being paid (see
  # Payments::WebhookHandler), so stock reserved for an abandoned card
  # checkout doesn't stay reserved forever. Locks each row the same way the
  # decrement does, for the same reason: correctness under concurrent
  # checkouts of the same product.
  def restore_stock!
    transaction do
      line_items.includes(:product, :product_variant)
        .sort_by { |line_item| [ line_item.product_id, line_item.product_variant_id || 0 ] }
        .each do |line_item|
          record = line_item.product_variant || line_item.product
          record.lock!
          record.increment!(:stock_quantity, line_item.quantity)
          record.sync_stock_status!
        end
    end
  end

  # Card orders only, with a real Stripe payment to refund, that haven't
  # already been refunded — guards both Payments::RefundIssuer (which would
  # otherwise happily re-refund an already-refunded order or blow up on a
  # missing payment_intent) and the admin Refund button's visibility.
  def refundable?
    card? && stripe_payment_intent_id.present? && refunded_cents.zero?
  end

  # A partial refund (e.g. issued directly from the Stripe Dashboard, not
  # through Payments::RefundIssuer, which is full-refund-only by design)
  # leaves refunded_cents positive without the order ever moving to the
  # "refunded" status — #refunded? alone can't tell the two apart, and
  # showing nothing at all for a partially-refunded order would hide real
  # money that's already gone back to the customer.
  def partially_refunded?
    refunded_cents.positive? && !refunded?
  end

  # Whether the physical items are still with us (never shipped) — the line
  # every stock-restoration decision is drawn on, whether the order is being
  # refunded or manually cancelled. An order that's already shipped/
  # delivered has real units out with the customer; putting them back into
  # sellable stock automatically would be a lie about what's actually in the
  # warehouse. Restoring only applies pre-shipment; a post-shipment return
  # is a manual admin stock adjustment once the item physically comes back,
  # since only the admin knows if/when that happens.
  def stock_restorable?
    !shipped? && !delivered?
  end

  # Payment status is deliberately separate from the fulfillment #status
  # enum above — a card order sitting at "pending"/"processing"/etc. has
  # already been paid (that's the only way it left awaiting_payment), but
  # showing an admin just "Pending" next to a card order is ambiguous about
  # whether the customer actually paid. This reads real, webhook-confirmed
  # Stripe state (stripe_payment_intent_id is only ever set by
  # Payments::WebhookHandler#handle_completed) rather than the fulfillment
  # status, so it stays correct regardless of how the order is fulfilled.
  # nil for Pay on Delivery — there's no Stripe payment to have a status.
  def stripe_payment_status
    return nil unless card?
    return :refunded if refunded?
    return :partially_refunded if partially_refunded?
    return :awaiting_payment if awaiting_payment?
    :paid
  end

  STRIPE_PAYMENT_STATUS_TONES = {
    awaiting_payment: :attention, paid: :positive, partially_refunded: :attention, refunded: :negative
  }.freeze

  def stripe_payment_status_tone
    STRIPE_PAYMENT_STATUS_TONES.fetch(stripe_payment_status, :neutral)
  end

  def stripe_dashboard_payment_intent_url
    stripe_dashboard_url("payments", stripe_payment_intent_id)
  end

  def stripe_dashboard_invoice_url
    stripe_dashboard_url("invoices", stripe_invoice_id)
  end

  private

  # Stripe's own dashboard uses this exact /test/ prefix for test-mode
  # resources — a real, stable URL pattern (visible in Stripe's own
  # dashboard breadcrumbs), not a guess. Built from Stripe.api_key rather
  # than an API call: an admin looking at this page wants a link to click,
  # not another round-trip to Stripe on every page load.
  def stripe_dashboard_url(resource, id)
    return nil if id.blank?
    mode_segment = Stripe.api_key.to_s.start_with?("sk_test_") ? "test/" : ""
    "https://dashboard.stripe.com/#{mode_segment}#{resource}/#{id}"
  end
end
