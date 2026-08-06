# frozen_string_literal: true

# Fail fast at boot, not at the customer's first checkout — without this, a
# missing STRIPE_TAX_RATE_ID or STRIPE_WEBHOOK_SECRET surfaced as a 500
# mid-request instead (both are read via bare ENV.fetch with no default,
# deep inside the checkout/webhook code paths).
#
# AWS_SES_SMTP_USERNAME/_PASSWORD deliberately NOT required here (explicit
# project-owner decision, 2026-08-06) — without them, Action Mailer's SMTP
# settings carry blank credentials and any real send (e.g. a password
# reset) fails at that point with an SMTP auth error, not at boot. Revisit
# once SES is actually configured on a given server.
if Rails.env.staging? || Rails.env.production?
  required = %w[
    ZOOMORA_TOYS_DATABASE_PASSWORD ZOOMORA_TOYS_DATABASE_HOST
    STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET STRIPE_TAX_RATE_ID
  ]
  missing = required.select { |key| ENV[key].blank? }
  raise "Missing required environment variables: #{missing.join(', ')}" if missing.any?
end
