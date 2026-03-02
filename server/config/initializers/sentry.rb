if ENV['SENTRY_DSN'].present?
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = %i[active_support_logger http_logger]

    # Set tracesSampleRate to 1.0 to capture 100%
    # of transactions for performance monitoring.
    # We recommend adjusting this value in production
    config.traces_sample_rate = 0.5

    config.enabled_environments = %w[production staging]
    config.enabled_environments << 'development' if ENV['SENTRY_REPORT_ON_DEVELOPMENT'].present?

    config.release = "spree@#{ENV['RENDER_GIT_COMMIT']}" if ENV['RENDER_GIT_COMMIT'].present?

    config.excluded_exceptions += [
      'ActionController::RoutingError',
      'ActiveRecord::RecordNotFound',
      'Sidekiq::JobRetry::Skip',
      'Sidekiq::JobRetry::SilentRetry',
      'Aws::S3::Errors::NoSuchKey',
      'Aws::S3::Errors::NotFound',
      'ActiveStorage::FileNotFoundError'
    ]

    # Use native Rails error subscriber
    # https://guides.rubyonrails.org/error_reporting.html
    config.rails.register_error_subscriber = true
  end
end
