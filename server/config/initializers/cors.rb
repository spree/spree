# Be sure to restart your server when you modify this file.

# CORS configuration for Spree API endpoints.
# This handles preflight OPTIONS requests from browser-based API clients.
#
# PRODUCTION: Replace the origins below with your actual frontend URLs.
# Examples:
#   origins 'https://mystore.com', 'https://admin.mystore.com'
#   origins /\Ahttps:\/\/.*\.mystore\.com\z/  # regex for subdomains
#
# You can also resolve origins dynamically from Spree::Store records:
#   origins do |source, env|
#     Spree::Store.pluck(:url).any? { |url| source.include?(url) }
#   end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.development? || Rails.env.test?
      origins '*'
    else
      origins ENV.fetch('CORS_ORIGINS', 'https://localhost:3000').split(',')
    end

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['X-Total-Count', 'X-Page', 'X-Per-Page'],
      max_age: 7200

    # Active Storage direct uploads (disk service uses Rails routes for PUT)
    resource '/rails/active_storage/*',
      headers: :any,
      methods: [:get, :put, :options, :head],
      max_age: 3600
  end
end
