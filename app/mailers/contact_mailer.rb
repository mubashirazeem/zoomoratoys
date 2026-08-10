class ContactMailer < ApplicationMailer
  ADMIN_EMAIL = "sales@zoomora.com"

  # Auto-reply to whoever submitted the form.
  def acknowledgement(contact_message)
    @contact_message = contact_message
    mail(to: contact_message.email, subject: "We've received your message — Zoomora Toys")
  end

  # Internal notification — previously nothing notified staff that a
  # contact form had even been submitted; it only ever landed in the
  # database. reply_to is the customer's own address so a staff member can
  # hit Reply and land directly in the customer's inbox.
  def new_submission(contact_message)
    @contact_message = contact_message
    mail(to: ADMIN_EMAIL, reply_to: contact_message.email, subject: "New contact form message: #{contact_message.subject}")
  end
end
