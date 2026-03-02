require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  if ENV["AWS_ACCESS_KEY_ID"].present? && ENV["AWS_SECRET_ACCESS_KEY"].present?
    config.active_storage.service = :amazon
  elsif ENV["CLOUDFLARE_ACCESS_KEY_ID"].present? && ENV["CLOUDFLARE_ACCESS_SECRET"].present? && ENV["CLOUDFLARE_ENDPOINT"].present?
    config.active_storage.service = :cloudflare
  else
    config.active_storage.service = :local
  end

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = ENV["RAILS_ASSUME_SSL"] != "false"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV["RAILS_FORCE_SSL"] != "false"

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use Redis for caching if REDIS_URL is set, otherwise fall back to memory store.
  if ENV["REDIS_URL"].present?
    config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
  else
    config.cache_store = :memory_store
  end

  # SMTP configuration via environment variables.
  # Works with any SMTP provider (Resend, Postmark, Mailgun, SendGrid, SES, etc.)
  if ENV["SMTP_HOST"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              ENV["SMTP_HOST"],
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      user_name:            ENV["SMTP_USERNAME"],
      password:             ENV["SMTP_PASSWORD"],
      authentication:       :plain,
      enable_starttls_auto: true
    }
  end

  config.action_mailer.default_url_options = { host: ENV.fetch("RAILS_HOST", "example.com") }
  config.action_mailer.default_options = { from: ENV["SMTP_FROM_ADDRESS"] } if ENV["SMTP_FROM_ADDRESS"].present?

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
