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
  # Must run before ensure_cart_has_items — a customer bouncing back from a
  # cancelled/failed Tabby attempt arrives here with an empty cart (see its
  # own comment); this is what hands their cart back before that check can
  # redirect them away from it.
  before_action :recover_from_incomplete_tabby_payment, only: :show
  before_action :recover_from_incomplete_tamara_payment, only: :show
  before_action :ensure_cart_has_items, only: [ :show, :create ]
  before_action :ensure_cart_is_purchasable, only: [ :show, :create ]

  def show
    @gift_wrap_cents = CartsController::GIFT_WRAP_CENTS
    @express_delivery_cents = CartsController::EXPRESS_DELIVERY_CENTS
    @addresses = current_user.addresses.ordered
    @tabby_rejection_message = Payments::Tabby::CheckEligibility.call(
      amount_cents: current_cart.total_cents, email: current_user.email, phone: @addresses.first&.phone
    )
    # Tamara's own contract is a plain eligible/ineligible boolean, not a
    # rejection message the way Tabby's pre-scoring returns one — per
    # Tamara's own onboarding checklist: "If ineligible, the Tamara option
    # should be greyed-out," no specific message required. Reuses that
    # same greyed-out treatment (rather than a separate UI state) when
    # tamara_production_ready? is false — see that method's own comment —
    # short-circuits before ever calling the real API in that case.
    @tamara_eligible = tamara_production_ready? && Payments::Tamara::CheckEligibility.call(
      amount_cents: current_cart.total_cents, email: current_user.email
    )
  end

  def create
    case params[:payment_method]
    when "card" then create_redirect_order(:card)
    when "tabby" then create_redirect_order(:tabby)
    when "tamara"
      # Guards the actual order-creation path, not just the #show radio's
      # visibility — hiding the option in the view is a UX nicety, but a
      # direct POST (bookmarked form, replayed request) would otherwise
      # still reach Payments::Tamara::CreateOrder and complete a full
      # checkout against whatever TAMARA_BASE_URL happens to be
      # configured. In production with sandbox credentials still in place,
      # that would let a real customer finish what looks like a normal,
      # successful order — confirmed, webhook fires, admin sees "paid" —
      # while no real money ever moves, because it hit Tamara's sandbox.
      if tamara_production_ready?
        create_redirect_order(:tamara)
      else
        redirect_to cart_path, alert: "Tamara isn't available right now. Please choose another payment method."
      end
    else create_pay_on_delivery_order
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
  rescue Payments::ProviderError => e
    Rails.logger.error("Checkout: #{params[:payment_method]} error creating session for user #{current_user.id}: #{e.message}")
    Sentry.capture_exception(e)
    redirect_to cart_path, alert: "We couldn't start your payment. Please try again or choose a different payment method."
  rescue Payments::SessionRejected => e
    # Deliberately not Rails.logger.error/Sentry — a reject is a business
    # outcome, not a failure (see Payments::SessionRejected). No web_url
    # exists to redirect to, so this re-renders checkout in place instead
    # of bouncing anywhere, with the provider's own message.
    #
    # current_cart.cart_items.reset is required here, not optional: by the
    # time this rescue runs, Order.create_from_cart! (inside the now-rolled-
    # back transaction) already called cart.cart_items.destroy_all on this
    # exact cart object. The DB rollback undoes the DELETE, but Rails does
    # not revert an in-memory association's cache when a transaction rolls
    # back — current_cart.cart_items stays loaded-and-empty in memory even
    # though the row is genuinely still there. Every view expression that
    # calls current_cart.total_cents/total_after_discount_cents fresh (the
    # TabbyCard price and the card-base-cents total on this very re-render)
    # would otherwise compute off that stale empty association and show
    # AED 0 — confirmed live: this is what Tabby's QA caught as the
    # TabbyCard snippet submitting price: 0 right after eligibility was
    # restored. @cart_items/@cart_subtotal_cents (used for the Order Summary
    # and the Pay on Delivery total) don't need this — set_cart already
    # captured them, correctly, before create_from_cart! ever ran. Same
    # fix Cart#merge_guest_into_user! already uses for the same reason.
    current_cart.cart_items.reset
    @gift_wrap_cents = CartsController::GIFT_WRAP_CENTS
    @express_delivery_cents = CartsController::EXPRESS_DELIVERY_CENTS
    @addresses = current_user.addresses.ordered
    @tabby_rejection_message = e.message
    flash.now[:alert] = e.message
    render :show, status: :unprocessable_content
  end

  def confirmation
    @order = current_user.orders.includes(line_items: :product).find_by!(order_number: params[:order_number])
  end

  # JSON re-score for the phone currently typed into the checkout Shipping
  # form. Uses the same inputs #show does on the first paint
  # (current_cart.total_cents, the signed-in email) so the result the
  # customer sees after editing their phone matches what a fresh page load
  # would give. Never raises — CheckEligibility already degrades a
  # slow/unreachable Tabby (or any malformed response) to nil = eligible.
  def tabby_eligibility
    message = Payments::Tabby::CheckEligibility.call(
      amount_cents: current_cart.total_cents,
      email: current_user.email,
      phone: params[:phone].to_s.strip.presence
    )
    render json: { eligible: message.nil?, message: message }
  end

  private

  # Tamara defaults to their sandbox host (see Payments::Tamara.base_url)
  # unless TAMARA_BASE_URL is explicitly set to their real production
  # host — a deliberate "safe direction" default. That default is exactly
  # what makes it possible to configure Tamara credentials on a production
  # server (stopping the checkout-page crash from missing credentials)
  # without also, silently, letting real customers complete full orders
  # against sandbox before real production credentials exist. Development/
  # staging intentionally skip this check — sandbox is the expected,
  # correct target there, not a stand-in for production being unready.
  def tamara_production_ready?
    Payments::Tamara.available?
  end

  # Card and Tabby both follow the exact same shape: create the order as
  # awaiting_payment, get back a URL to redirect the customer to, and let
  # that provider's own webhook (never the browser redirect back) confirm
  # the order is actually paid. Shared here instead of duplicated.
  #
  # redirect_url, not checkout_url — this controller already has a
  # checkout_url route helper for /checkout (singular `resource :checkout`),
  # and assigning a local of that same name would shadow the helper for the
  # rest of this method, including inside this very call's own cancel_url:
  # argument (Ruby resolves a bare identifier to a local the moment the
  # parser has seen an assignment to that name anywhere earlier in the same
  # statement, even though it hasn't run yet) — silently passing nil.
  def create_redirect_order(provider)
    common_args = {
      cart: current_cart, user: current_user, shipping_attributes: shipping_attributes,
      gift_wrap: params[:gift_wrap].present?, gift_wrap_cents: CartsController::GIFT_WRAP_CENTS,
      gift_wrap_name: params[:gift_wrap_name], delivery_method: selected_delivery_method,
      delivery_fee_cents: CartsController::EXPRESS_DELIVERY_CENTS,
      success_url_for: ->(order) { checkout_confirmation_url(order.order_number) },
      cancel_url: checkout_url
    }

    redirect_url = case provider
    when :card
      Payments::CreateCardOrder.call(**common_args)
    when :tabby
      # Distinct cancel_url/failure_url (not the shared common_args one) —
      # tagged with the outcome so recover_from_incomplete_tabby_payment
      # can show the right message for each, per Tabby's own QA: showing
      # nothing at all on either redirect isn't acceptable.
      Payments::Tabby::CreateOrder.call(
        **common_args,
        cancel_url: checkout_url(tabby_outcome: "cancelled"),
        failure_url: checkout_url(tabby_outcome: "failed")
      )
    when :tamara
      # Both point at the same checkout page — Payments::Tamara::CreateOrder
      # itself tags each with tamara_recover/tamara_outcome (mirroring
      # Payments::Tabby::SessionBuilder#with_recovery_param), which is what
      # recover_from_incomplete_tamara_payment keys off below.
      Payments::Tamara::CreateOrder.call(
        **common_args,
        cancel_url: checkout_url,
        failure_url: checkout_url,
        notification_url: tamara_webhooks_url
      )
    end

    save_address_for_next_time if params[:save_address].present?
    redirect_to redirect_url, allow_other_host: true
  end

  def create_pay_on_delivery_order
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
    # Pay on Delivery is fully placed the moment this line runs (no
    # provider to wait on) — card/Tabby orders are confirmed by mail once
    # their own webhook hears back instead (see each provider's
    # WebhookHandler).
    OrderMailer.confirmation(order).deliver_later
    AdminMailer.new_order(order).deliver_later
    redirect_to checkout_confirmation_path(order.order_number)
  end

  # Tabby's own testing checklist: "the cart is kept after cancellation/
  # failure and cleared after a successful payment." Order.create_from_cart!
  # already destroys the cart the moment an order is placed (needed so a
  # second Place Order click can't reserve the same stock twice) — so a
  # customer bounced back here via Tabby's cancel/failure URL (tagged with
  # tabby_recover=<order_number>, see SessionBuilder) would otherwise land
  # on an empty cart with no way to retry. This puts their items back and
  # releases the abandoned order's stock reservation in the same breath,
  # so there's never a moment with both the cart and the reservation alive
  # at once.
  #
  # with_lock + the awaiting_payment? check make this safe against the
  # rare race where a webhook confirms this exact payment at the same
  # moment: whichever of the two commits first wins, and the other finds
  # the order already moved on and no-ops — same pattern as
  # Payments::WebhookHandler#handle_expired.
  # Tabby's own approved copy, verbatim — docs.tabby.ai/pay-in-4-custom-
  # integration/checkout-flow#approved-messages-for-redirects. Not a
  # paraphrase: this checklist expects the exact text, the same way the
  # payment method label had to be exactly "Pay later with Tabby".
  RECOVERY_MESSAGES = {
    "cancelled" => "You aborted the payment. Please retry or choose another payment method.",
    "failed" => "Sorry, Tabby is unable to approve this purchase. Please use an alternative payment method for your order"
  }.freeze

  def recover_from_incomplete_tabby_payment
    return if params[:tabby_recover].blank?

    order = current_user.orders.find_by(order_number: params[:tabby_recover], payment_method: "tabby")
    return unless order

    recovered = false

    order.with_lock do
      # Rejected payments race the webhook: Tabby can call
      # Payments::Tabby::WebhookHandler#handle_failed (which cancels the
      # order + restores stock) before the browser even finishes
      # redirecting back here — much faster than a cancellation, which
      # never fires a webhook at all since nothing was ever decided
      # server-side. That race is exactly why rejection alone showed an
      # empty cart with no message: the old `awaiting_payment?`-only guard
      # treated an order the webhook had already resolved as nothing left
      # to do. cart_restored_at is the real idempotency key now — separate
      # from order status, so a webhook that got there first doesn't
      # block the customer from getting their cart back, and a repeat
      # visit to this same URL can't double-add cart items.
      next if order.cart_restored_at.present?
      next unless order.awaiting_payment? || order.cancelled?

      recovered = true
      cart = persisted_cart # current_cart may be a new, unsaved record — needs a row to attach cart_items to
      order.line_items.includes(:product, :product_variant).each do |line_item|
        # find_or_… by product+variant, not a plain create! — the customer
        # may have already re-added this same product in another tab while
        # this order sat awaiting_payment, and cart_items has a unique
        # index on [cart_id, product_id, product_variant_id] (same merge
        # pattern as CartItemsController#create).
        existing = cart.cart_items.find_by(product: line_item.product, product_variant: line_item.product_variant)
        if existing
          existing.update!(quantity: existing.quantity + line_item.quantity)
        else
          cart.cart_items.create!(
            product: line_item.product, product_variant: line_item.product_variant, quantity: line_item.quantity
          )
        end
      end
      order.restore_stock! if order.awaiting_payment? # webhook already restored it if we're not
      order.update!(status: "cancelled", cart_restored_at: Time.current)
    end

    # Deliberately NOT gated on `recovered` alone: that flag is only true on
    # the one request that actually ran the cart-merge above, so gating the
    # rest on it too meant a second hit to this exact URL — a plain browser
    # refresh, back/forward, or revisiting it from history — rendered the
    # shipping form blank and delivery/gift-wrap back to their defaults,
    # even though the cart items themselves (already persisted to the real
    # cart row) were still there. order.cart_restored_at.present? is true
    # both on the request that just set it and on every later visit, so the
    # fallback below now survives a refresh the same way the cart itself
    # already does.
    return unless recovered || order.cart_restored_at.present?

    # Tabby's cancel/failure redirect only ever carries tabby_recover/
    # tabby_outcome — none of the shipping form fields the customer had
    # already typed. Without this, the form comes back blank and the
    # customer can't actually complete the order with another payment
    # method (the whole point of keeping the cart) without retyping
    # everything first. The order still has exactly what they entered.
    @recovered_order = order
    # Only shown on the request that actually performed the recovery —
    # standard one-time flash.now semantics, same as everywhere else in the
    # app; a refresh naturally drops it, same as the cancellation path.
    flash.now[:alert] = RECOVERY_MESSAGES.fetch(params[:tabby_outcome], RECOVERY_MESSAGES["failed"]) if recovered
    # ApplicationController's own before_action :set_cart already ran (it's
    # registered on the parent class, so it always runs before this
    # controller's own before_actions) and computed @cart_items/
    # @cart_subtotal_cents from the cart as it was *before* the items above
    # were restored — still empty at that point. Re-running it is what
    # fixed the real bug Tabby's own QA caught: the Total staying AED 0
    # until a manual reload, because nothing had refreshed those ivars
    # after the restore.
    set_cart
  end

  # Tamara's own equivalent of RECOVERY_MESSAGES above — not Tamara's own
  # approved copy the way Tabby's is (no such requirement has surfaced for
  # Tamara), just clear, honest merchant-voice text.
  #
  # One message, not split by outcome like Tabby's: a real live test (a
  # genuine decline, using Tamara's own documented decline-test phone
  # number) redirected through merchant_url.cancel, not merchant_url.
  # failure — contradicting the Tabby-mirrored assumption this originally
  # shipped with, that cancel==voluntary-abandon and failure==declined.
  # Tamara's own docs don't define the distinction precisely enough to
  # trust either slot as reliable proof of *why* the payment didn't
  # happen, so this deliberately doesn't claim a specific reason ("you
  # cancelled" would be actively wrong to tell a declined customer) —
  # tamara_outcome is still tagged on the URL (kept for logging/debugging)
  # but no longer decides which text shows.
  TAMARA_RECOVERY_MESSAGE =
    "Your Tamara payment wasn't completed. Your cart is unchanged, so you can retry or choose another payment method.".freeze

  # Same shape as recover_from_incomplete_tabby_payment above, deliberately
  # kept as its own separate method rather than merged/shared — Tabby's
  # version is battle-tested against months of real QA findings, and
  # touching it while adding Tamara risks regressing it. See that method's
  # own comments for the full reasoning (webhook-vs-redirect race,
  # cart_restored_at as the real idempotency key, refresh-persistence);
  # this mirrors all of it for tamara_recover.
  #
  # The race is real here too: Tamara's decline decision happens
  # synchronously during OTP/scoring (confirmed live — the browser lands
  # back here within a couple seconds of entering the OTP), fast enough
  # that Payments::Tamara::WebhookHandler#handle_failed can plausibly beat
  # this redirect the same way Tabby's rejection webhook can.
  def recover_from_incomplete_tamara_payment
    return if params[:tamara_recover].blank?

    order = current_user.orders.find_by(order_number: params[:tamara_recover], payment_method: "tamara")
    return unless order

    recovered = false

    order.with_lock do
      next if order.cart_restored_at.present?
      next unless order.awaiting_payment? || order.cancelled?

      recovered = true
      cart = persisted_cart
      order.line_items.includes(:product, :product_variant).each do |line_item|
        existing = cart.cart_items.find_by(product: line_item.product, product_variant: line_item.product_variant)
        if existing
          existing.update!(quantity: existing.quantity + line_item.quantity)
        else
          cart.cart_items.create!(
            product: line_item.product, product_variant: line_item.product_variant, quantity: line_item.quantity
          )
        end
      end
      order.restore_stock! if order.awaiting_payment?
      order.update!(status: "cancelled", cart_restored_at: Time.current)
    end

    return unless recovered || order.cart_restored_at.present?

    @recovered_order = order
    flash.now[:alert] = TAMARA_RECOVERY_MESSAGE if recovered
    set_cart
  end

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
