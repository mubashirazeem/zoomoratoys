# spec/support/vcr.rb
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Only Stripe's API is ever intercepted — every other request this suite
  # makes (its own request-spec traffic, anything else) passes through
  # exactly as it does today.
  config.ignore_request do |request|
    !URI(request.uri).host.end_with?("stripe.com")
  end

  # Cassettes are recorded once against the real key (exported on the
  # command line, see the recording step in Task 4) and replayed
  # afterward — never re-recorded automatically just because the request
  # doesn't match byte-for-byte, which would silently mask a real
  # integration bug as "just re-record it."
  config.default_cassette_options = { record: :once }

  # Never let a real secret key leak into a committed cassette file.
  config.filter_sensitive_data("<STRIPE_SECRET_KEY>") { ENV["STRIPE_SECRET_KEY"] }
end
