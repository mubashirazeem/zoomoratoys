namespace :stripe do
  desc "One-time setup: create the 5% inclusive UAE VAT tax rate in Stripe and print its id"
  task create_tax_rate: :environment do
    tax_rate = Stripe::TaxRate.create(
      display_name: "VAT",
      percentage: 5.0,
      inclusive: true,
      country: "AE",
      description: "UAE VAT (5%, inclusive)"
    )

    puts "Created Stripe Tax Rate: #{tax_rate.id}"
    puts "Add this as STRIPE_TAX_RATE_ID=#{tax_rate.id} wherever STRIPE_SECRET_KEY for this Stripe account is set."
  end

  desc "One-time setup: create a real Stripe webhook endpoint pointed at the given URL, and print its signing secret"
  task :create_webhook_endpoint, [ :url ] => :environment do |_, args|
    url = args[:url] || raise('Usage: rake "stripe:create_webhook_endpoint[https://staging.zoomora.com/stripe/webhooks]"')

    endpoint = Stripe::WebhookEndpoint.create(
      url: url,
      enabled_events: %w[
        checkout.session.completed
        checkout.session.async_payment_succeeded
        checkout.session.expired
        checkout.session.async_payment_failed
        charge.refunded
        charge.dispute.created
        charge.dispute.closed
      ]
    )

    puts "Created webhook endpoint: #{endpoint.id} -> #{url}"
    puts "Add this as STRIPE_WEBHOOK_SECRET=#{endpoint.secret} on the server this URL points at."
    puts "(This secret is only ever shown once, at creation time — Stripe won't show it again.)"
  end
end
