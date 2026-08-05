source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.3", ">= 7.2.3.1"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# S3 storage backend for Active Storage in production [https://github.com/aws/aws-sdk-ruby]
gem "aws-sdk-s3", require: false
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# View-layer components with encapsulated templates and unit tests [https://viewcomponent.org]
gem "view_component"
# Flexible authentication solution for Rails with Warden [https://github.com/heartcombo/devise]
gem "devise"
# Pagination [https://github.com/kaminari/kaminari]
gem "kaminari"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.0"

# Audit trail — who changed what, when [https://github.com/paper-trail-gem/paper_trail]
gem "paper_trail"

# Rate-limit/throttle abusive requests (login brute-forcing, checkout spam) [https://github.com/rack/rack-attack]
gem "rack-attack"

# XML sitemap generation for search engines [https://github.com/kjvarga/sitemap_generator]
gem "sitemap_generator"

# Payments — real Stripe card checkout as a second payment method
# alongside Pay on Delivery (Milestone 4) [https://github.com/stripe/stripe-ruby]
gem "stripe"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Checks Gemfile.lock dependencies against the known CVE database [https://github.com/rubysec/bundler-audit]
  gem "bundler-audit", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec test framework for Rails [https://github.com/rspec/rspec-rails]
  gem "rspec-rails"

  # Matchers for asserting on rendered markup in component/system specs [https://github.com/teamcapybara/capybara]
  gem "capybara"

  # Fixtures replacement with a straightforward definition syntax [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails"

  # Library for generating realistic seed/test data [https://github.com/faker-ruby/faker]
  gem "faker"

  # Concise, readable one-liner matchers for validations/associations [https://github.com/thoughtbot/shoulda-matchers]
  gem "shoulda-matchers"

  # Loads STRIPE_SECRET_KEY etc. from .env in development/test — production
  # sets real environment variables via the hosting platform directly, never
  # a committed file [https://github.com/bkeepers/dotenv]
  gem "dotenv-rails"

  # Deploy tooling — only ever run from a developer's machine against a
  # remote server, never loaded by the app itself [https://github.com/capistrano/capistrano]
  gem "capistrano", "~> 3.19", require: false
  gem "capistrano-rails", "~> 1.6", require: false
  gem "capistrano-passenger", "~> 0.2.1", require: false
  gem "capistrano-rbenv", "~> 2.2", require: false
end

group :test do
  # Records real HTTP exchanges with Stripe's test-mode API once, replays
  # them deterministically after — stays closest to this suite's "real, not
  # mocked" convention for the one external paid API this app talks to
  # [https://github.com/vcr/vcr]
  gem "vcr"

  # VCR's HTTP interception layer. Scoped (see spec/support/vcr.rb) to only
  # intercept api.stripe.com — every other request in this suite is
  # unaffected [https://github.com/bblimke/webmock]
  gem "webmock"
end

group :development do
  # Detects N+1 queries and unused eager loading, logged to the Rails log
  # and browser console — the same kind of missed-eager-load bug that's
  # been found and fixed by hand repeatedly across this app (product
  # images, nav categories, cart) [https://github.com/flyerhzm/bullet]
  gem "bullet"

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Highlight the fine-grained location where an error occurred [https://github.com/ruby/error_highlight]
  # Pinned to exactly 0.6.0 (not ">= 0.4.0") to match the version actually
  # baked into Ruby 3.3.5 as a default gem. A loose ">=" constraint lets
  # Bundler resolve to the latest published version (0.7.0) instead, which
  # installs and works fine on a machine that happens to already have it —
  # but breaks on any *fresh* Ruby 3.3.5 (e.g. GitHub Actions' hosted
  # runners), where 0.6.0 is already activated as a default gem before
  # Bundler runs, and Ruby can't swap an already-activated default gem for
  # a different version mid-process. Surfaced by bin/brakeman failing in CI
  # with "You have already activated error_highlight 0.6.0, but your
  # Gemfile requires 0.7.0."
  gem "error_highlight", "0.6.0", platforms: [ :ruby ]
end
