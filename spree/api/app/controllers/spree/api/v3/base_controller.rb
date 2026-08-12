module Spree
  module Api
    module V3
      class BaseController < ActionController::API
        # API v3 uses flat params — disable Rails' automatic parameter wrapping
        wrap_parameters false

        include ActiveStorage::SetCurrent
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        include Spree::Core::ControllerHelpers::Store
        include Spree::Api::V3::LocaleAndCurrency
        include Spree::Api::V3::JwtAuthentication
        include Spree::Api::V3::ApiKeyAuthentication
        include Spree::Api::V3::ErrorHandler
        include Spree::Api::V3::SecurityHeaders
        include Spree::Api::V3::ResourceSerializer
        include Spree::Api::V3::RateLimitHeaders
        include Spree::Api::V3::Idempotent
        include Pagy::Method

        RATE_LIMIT_RESPONSE = -> { render_rate_limited }

        # One global budget per caller (see RateLimitHeaders for the bucket
        # rules); the two declarations are mutually exclusive so a request
        # only ever counts against one ceiling.
        rate_limit to: Spree::Api::Config[:rate_limit_per_secret_key], within: Spree::Api::Config[:rate_limit_window].seconds,
                   store: Rails.cache,
                   scope: RateLimitHeaders::RATE_LIMIT_SCOPE,
                   by: :rate_limit_bucket,
                   with: RATE_LIMIT_RESPONSE,
                   if: :secret_key_request?

        rate_limit to: Spree::Api::Config[:rate_limit_per_key], within: Spree::Api::Config[:rate_limit_window].seconds,
                   store: Rails.cache,
                   scope: RateLimitHeaders::RATE_LIMIT_SCOPE,
                   by: :rate_limit_bucket,
                   with: RATE_LIMIT_RESPONSE,
                   unless: :secret_key_request?

        # Optional JWT authentication by default
        before_action :authenticate_user

        protected

        # Refuses a throttled request. Must render (not return a value) —
        # Rails runs `with:` responders via instance_exec inside a
        # before_action, where only render/redirect halts the chain. Headers
        # are set here because a halted chain skips after_actions, so
        # RateLimitHeaders never runs for a 429. Endpoint throttles pass the
        # +limit+ that actually tripped so the header reports their ceiling,
        # not the API-wide one.
        def render_rate_limited(limit: rate_limit_ceiling)
          response.headers['Retry-After'] = Spree::Api::Config[:rate_limit_window].to_s
          response.headers['X-RateLimit-Limit'] = limit.to_s
          response.headers['X-RateLimit-Remaining'] = '0'
          render json: { error: { code: 'rate_limit_exceeded', message: 'Too many requests. Please retry later.' } },
                 status: :too_many_requests
        end

        # Override to use current_user from JWT authentication
        # @return [Spree.user_class]
        def spree_current_user
          current_user
        end

        alias try_spree_current_user spree_current_user

        # CanCanCan ability
        # @return [Spree::Ability]
        def current_ability
          @current_ability ||= Spree::Ability.new(current_user, ability_options)
        end

        # Options passed to the CanCanCan ability
        # @return [Hash]
        def ability_options
          { store: current_store }
        end
      end
    end
  end
end
