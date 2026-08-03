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

        RATE_LIMIT_RESPONSE = -> {
          limit = Spree::Api::Config[:rate_limit_per_key]
          window = Spree::Api::Config[:rate_limit_window]
          body = { error: { code: 'rate_limit_exceeded', message: 'Too many requests. Please retry later.' } }
          headers = {
            'Content-Type' => 'application/json',
            'Retry-After' => window.to_s,
            'X-RateLimit-Limit' => limit.to_s,
            'X-RateLimit-Remaining' => '0'
          }
          [429, headers, [body.to_json]]
        }

        rate_limit to: Spree::Api::Config[:rate_limit_per_key], within: Spree::Api::Config[:rate_limit_window].seconds,
                   store: Rails.cache,
                   by: -> { request.headers['X-Spree-Api-Key'] || request.remote_ip },
                   with: RATE_LIMIT_RESPONSE

        # Optional JWT authentication by default
        before_action :authenticate_user

        protected

        # Guest authorization for a specific order or cart. Defined here
        # because Store::BaseController and Store::ResourceController anchor
        # parallel inheritance branches — both need it.
        def order_token
          request.headers['x-spree-token']
        end

        # Renders a failed service/workflow Result: validation errors become a
        # 422 field-error payload, anything else a plain service error. Shared
        # by both APIs — Store endpoints surface workflow failures (a rejected
        # return, a vetoed cart add) the same way Admin ones do.
        def render_result_error(result)
          error = result.error
          errors = error.respond_to?(:value) ? error.value : error

          if errors.is_a?(ActiveModel::Errors)
            render_validation_error(errors)
          else
            render_service_error(error)
          end
        end

        # Override to use current_user from JWT authentication
        # @return [Spree.customer_class]
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
