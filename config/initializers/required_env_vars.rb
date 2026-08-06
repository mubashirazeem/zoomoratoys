# frozen_string_literal: true

# Fail fast at boot, not at the customer's first checkout/password-reset —
# without this, a missing STRIPE_TAX_RATE_ID or STRIPE_WEBHOOK_SECRET
# surfaced as a 500 mid-request instead (both are read via bare ENV.fetch
# with no default, deep inside the checkout/webhook code paths).
if Rails.env.staging? || Rails.env.production?
  required = %w[
    ZOOMORA_TOYS_DATABASE_PASSWORD ZOOMORA_TOYS_DATABASE_HOST
    STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET STRIPE_TAX_RATE_ID
    AWS_SES_SMTP_USERNAME AWS_SES_SMTP_PASSWORD
  ]
  missing = required.select { |key| ENV[key].blank? }
  raise "Missing required environment variables: #{missing.join(', ')}" if missing.any?
end
