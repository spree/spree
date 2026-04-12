require 'spree/core/preferences/runtime_configuration'

module Spree
  module Api
    class Configuration < Spree::Preferences::RuntimeConfiguration
      preference :jwt_expiration, :integer, default: 3600 # 1 hour in seconds
      preference :jwt_secret_key, :string, default: nil
      preference :refresh_token_expiry, :integer, default: 2_592_000 # 30 days in seconds

      # Rate limiting
      preference :rate_limit_per_key, :integer, default: 300 # per publishable API key
      preference :rate_limit_window, :integer, default: 60 # window in seconds
      preference :rate_limit_login, :integer, default: 5 # per IP
      preference :rate_limit_register, :integer, default: 3 # per IP
      preference :rate_limit_refresh, :integer, default: 10 # per IP
      preference :rate_limit_oauth, :integer, default: 5 # per IP
      preference :rate_limit_password_reset, :integer, default: 3 # per IP

      # Request body size limit in bytes
      preference :max_request_body_size, :integer, default: 102_400 # 100KB

      preference :webhooks_enabled, :boolean, default: true
      preference :webhooks_verify_ssl, :boolean, default: !Rails.env.development?
    end
  end
end
