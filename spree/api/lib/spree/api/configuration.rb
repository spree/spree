require 'spree/core/preferences/runtime_configuration'

module Spree
  module Api
    class Configuration < Spree::Preferences::RuntimeConfiguration
      preference :jwt_expiration, :integer, default: 3600, env: 'SPREE_JWT_EXPIRATION' # 1 hour in seconds (customer/store JWT default)
      preference :admin_jwt_expiration, :integer, default: 300, env: 'SPREE_ADMIN_JWT_EXPIRATION' # 5 minutes — admin tokens have higher blast radius
      # SPREE_JWT_SECRET_KEY resolves inside the preference, so it sits ahead of
      # the Rails credentials fallback in Spree::Api::V3::JwtAuthentication —
      # an operator who sets it means it. The older, unprefixed JWT_SECRET_KEY
      # keeps its place behind credentials so existing deployments are
      # unaffected.
      preference :jwt_secret_key, :string, default: nil, env: 'SPREE_JWT_SECRET_KEY'
      preference :refresh_token_expiry, :integer, default: 2_592_000, env: 'SPREE_REFRESH_TOKEN_EXPIRY' # 30 days in seconds

      # Rate limiting
      preference :rate_limit_per_key, :integer, default: 300, env: 'SPREE_RATE_LIMIT_PER_KEY' # per publishable API key + client IP (per visitor)
      preference :rate_limit_per_secret_key, :integer, default: 600, env: 'SPREE_RATE_LIMIT_PER_SECRET_KEY' # per secret API key, across the whole API
      preference :rate_limit_window, :integer, default: 60, env: 'SPREE_RATE_LIMIT_WINDOW' # window in seconds
      preference :rate_limit_login, :integer, default: 5, env: 'SPREE_RATE_LIMIT_LOGIN' # per IP
      preference :rate_limit_register, :integer, default: 3, env: 'SPREE_RATE_LIMIT_REGISTER' # per IP
      preference :rate_limit_refresh, :integer, default: 10, env: 'SPREE_RATE_LIMIT_REFRESH' # per IP
      preference :rate_limit_password_reset, :integer, default: 3, env: 'SPREE_RATE_LIMIT_PASSWORD_RESET' # per IP

      # Request body size limit in bytes
      preference :max_request_body_size, :integer, default: 102_400, env: 'SPREE_MAX_REQUEST_BODY_SIZE' # 100KB

      preference :webhooks_enabled, :boolean, default: true, env: 'SPREE_WEBHOOKS_ENABLED'
      preference :webhooks_verify_ssl, :boolean, default: !Rails.env.development?, env: 'SPREE_WEBHOOKS_VERIFY_SSL'
    end
  end
end
