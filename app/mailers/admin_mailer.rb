# Internal notifications to the sales inbox — never customer-facing.
class AdminMailer < ApplicationMailer
  ADMIN_EMAIL = "sales@zoomora.com"

  def new_order(order)
    @order = order
    mail(to: ADMIN_EMAIL, subject: "New order — #{order.order_number} (AED #{order.total_cents / 100})")
  end
end
