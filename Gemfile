source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.3", ">= 7.2.3.1"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
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
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

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
end

group :development do
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
