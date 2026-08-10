class NewsletterMailer < ApplicationMailer
  default from: "Zoomora Toys <marketing@zoomora.com>"

  # Authenticates as marketing@zoomora.com (its own real Zoho mailbox)
  # rather than ApplicationMailer's sales@zoomora.com default — Zoho
  # rejects mail where the From header doesn't match the authenticated
  # SMTP account unless a "Send Mail As" alias is configured, so each
  # purpose-specific mailbox gets its own SMTP login instead. Only ever
  # consulted when delivery_method resolves to :smtp (production) — inert
  # in development/test, which use different delivery methods entirely.
  # ssl: true, not enable_starttls_auto — see production.rb's own
  # ApplicationMailer smtp_settings comment for why.
  self.smtp_settings = {
    address: ENV["SMTP_ADDRESS"],
    port: ENV.fetch("SMTP_PORT", 465),
    user_name: ENV["SMTP_MARKETING_USERNAME"],
    password: ENV["SMTP_MARKETING_PASSWORD"],
    authentication: :login,
    ssl: true
  }

  def welcome(subscriber)
    @subscriber = subscriber
    mail(to: subscriber.email, subject: "Welcome to Zoomora Toys")
  end
end
