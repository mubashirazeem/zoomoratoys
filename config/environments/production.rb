require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  # config.public_file_server.enabled = false

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Real product photo uploads live in S3 (see config/storage.yml) — the
  # production EC2 instance authenticates via its attached IAM role.
  config.active_storage.service = :amazon

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Nginx/Passenger terminates TLS and forwards X-Forwarded-Proto — without
  # this, force_ssl below can't tell the request was already secure.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint — a
  # plain-HTTP load balancer/uptime probe should get 200, not a 301.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to both a plain file under log/ (readable directly with tail/cat/less
  # as the deploy user — no sudo needed, unlike Passenger's nginx-owned
  # stdout capture — since `log` is already a Capistrano linked_dir) and
  # STDOUT (kept too, in case anything else depends on Passenger's capture
  # of it). Rotates at 50MB, keeping 5 old files, so it can't fill the disk.
  file_logger = ActiveSupport::Logger.new(Rails.root.join("log", "production.log"), 5, 50.megabytes)
  stdout_logger = ActiveSupport::Logger.new(STDOUT)
  [ file_logger, stdout_logger ].each { |logger| logger.formatter = ::Logger::Formatter.new }

  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::BroadcastLogger.new(file_logger, stdout_logger))

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Plain file-based cache, not Redis — this app deploys to a single server
  # (see config/deploy/production.rb), so there's nothing to share a cache
  # across. tmp/cache is already a Capistrano linked_dir, so this survives
  # deploys. Revisit only if a second app server is ever added.
  config.cache_store = :file_store, Rails.root.join("tmp", "cache")

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "zoomora_toys_production"

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  # Required by Devise for building links (password reset, confirmation) in
  # emails — update if the production domain changes.
  config.action_mailer.default_url_options = { host: "zoomora.com" }

  # Without this, Rails defaults to SMTP against localhost:25, which fails on
  # every real host — password resets would error out on send.
  # AWS_SES_SMTP_USERNAME/_PASSWORD are set on the server via its
  # .rbenv-vars file, never committed here.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "email-smtp.us-east-1.amazonaws.com",
    port: 587,
    user_name: ENV["AWS_SES_SMTP_USERNAME"],
    password: ENV["AWS_SES_SMTP_PASSWORD"],
    authentication: :login,
    enable_starttls_auto: true
  }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks. Without
  # this, an attacker-supplied Host header reflects into request.base_url —
  # used for the canonical URL, og:url, and JSON-LD in app/views/layouts/_head.html.erb.
  config.hosts = [ "zoomora.com", /.*\.zoomora\.com/ ]
  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
