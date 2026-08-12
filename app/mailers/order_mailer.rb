require "open-uri"

# Customer-facing order lifecycle emails. Every action here is triggered
# explicitly from the call site that owns the state transition (checkout,
# Payments::WebhookHandler, Payments::RefundIssuer, Admin::OrdersController)
# — never from an Order callback — matching how the rest of this app keeps
# side effects visible at the call site rather than hidden in the model.
class OrderMailer < ApplicationMailer
  # Sent once per order: immediately for Pay on Delivery (including
  # admin-created phone/WhatsApp orders), or once Payments::WebhookHandler
  # confirms a card payment. Attaches the real Stripe-generated invoice PDF
  # when one exists (card orders only — Stripe's Checkout Session is built
  # with invoice_creation: { enabled: true }, see
  # Payments::StripeCheckoutSessionBuilder).
  def confirmation(order)
    @order = order
    attach_stripe_invoice(order)
    mail(to: order.user.email, subject: "Order confirmed — #{order.order_number}")
  end

  def shipped(order)
    @order = order
    mail(to: order.user.email, subject: "Your order has shipped — #{order.order_number}")
  end

  def refunded(order)
    @order = order
    mail(to: order.user.email, subject: "Your order has been refunded — #{order.order_number}")
  end

  # Admin-initiated cancellation only (Admin::OrdersController#update) — a
  # card order that simply expired unpaid (Payments::WebhookHandler#handle_expired)
  # was never a real order the customer needs to hear about; they already
  # know they didn't complete payment.
  def cancelled(order)
    @order = order
    mail(to: order.user.email, subject: "Your order has been cancelled — #{order.order_number}")
  end

  private

  # Best-effort: a Stripe hiccup fetching the PDF must never stop the
  # confirmation email itself from sending — same defensive posture as
  # Payments::WebhookHandler#hosted_invoice_url_for.
  def attach_stripe_invoice(order)
    return if order.stripe_invoice_id.blank?

    invoice = Stripe::Invoice.retrieve(order.stripe_invoice_id)
    return if invoice.invoice_pdf.blank?

    pdf_data = URI.parse(invoice.invoice_pdf).open.read
    attachments["#{order.order_number}-invoice.pdf"] = { mime_type: "application/pdf", content: pdf_data }
  # SystemCallError covers the raw Errno::ECONNRESET/ETIMEDOUT/ECONNREFUSED
  # family a mid-download connection drop actually raises (confirmed live:
  # a real invoice download hit Errno::ECONNRESET mid-transfer and, before
  # this line covered it, took the entire confirmation email down with it —
  # exactly what this rescue's own comment says must never happen).
  # OpenSSL::SSL::SSLError covers the TLS-level equivalent.
  rescue Stripe::StripeError, OpenURI::HTTPError, SocketError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError => e
    Rails.logger.error("OrderMailer: failed to attach Stripe invoice for order #{order.order_number}: #{e.message}")
    Sentry.capture_exception(e)
  end
end
