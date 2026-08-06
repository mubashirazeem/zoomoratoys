# frozen_string_literal: true

# Free at sentry.io (Developer plan — confirm current limits on their
# pricing page, they change over time). Sign up, create a Rails project,
# and paste the DSN it gives you into SENTRY_DSN (see .env.example / the
# server's .rbenv-vars). Entirely inert with no DSN set — dev/test/CI never
# configure one, so nothing here runs for them.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = Rails.env
    config.breadcrumbs_logger = [ :active_support_logger ]
    # Errors are always captured; this instead controls performance-trace
    # sampling, which counts separately against the free tier's quota — kept
    # low rather than off, so a real slow-request pattern is still visible.
    config.traces_sample_rate = 0.1
  end
end
