# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle://preflight `OPTIONS` requests.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['X-Total-Count', 'X-Page', 'X-Per-Page'],
      max_age: 7200
  end
end
