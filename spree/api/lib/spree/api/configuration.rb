require 'spree/core/preferences/runtime_configuration'

module Spree
  module Api
    class Configuration < Spree::Preferences::RuntimeConfiguration
      preference :api_v2_serializers_cache_ttl, :integer, default: 3600 # 1 hour in seconds
      preference :api_v2_collection_cache_ttl, :integer, default: 3600 # 1 hour in seconds
      preference :api_v2_collection_cache_namespace, :string, default: 'api_v2_collection_cache'
      preference :api_v2_content_type, :string, default: 'application/vnd.api+json'
      preference :api_v2_per_page_limit, :integer, default: 500

      preference :jwt_expiration, :integer, default: 3600 # 1 hour in seconds

      # Rate limiting (requests per minute)
      preference :rate_limit_per_key, :integer, default: 300 # per publishable API key
      preference :rate_limit_login, :integer, default: 5 # per IP
      preference :rate_limit_register, :integer, default: 3 # per IP
      preference :rate_limit_refresh, :integer, default: 10 # per IP
      preference :rate_limit_oauth, :integer, default: 5 # per IP

      # Request body size limit in bytes
      preference :max_request_body_size, :integer, default: 102_400 # 100KB

      preference :webhooks_enabled, :boolean, default: true
      preference :webhooks_verify_ssl, :boolean, default: !Rails.env.development?
    end
  end
end
