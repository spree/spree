module Spree
  module Api
    module V3
      module Seller
        # Sign-in for the marketplace seller panel.
        #
        # Its own surface rather than a reuse of the admin one, so login policy
        # can differ per panel: a store that requires SSO for its own staff can
        # still let sellers sign in with a password, because the two read
        # different strategy registries against the same user class.
        class AuthController < Seller::BaseController
          include Spree::Api::V3::Seller::AuthCookies
          include Spree::Api::V3::AuthenticationStrategies

          skip_scope_check!

          # A distinct `name:` per declaration — without one Rails keys every
          # counter in the controller on one cache entry, so the provider list
          # a login page fetches on every load would spend the login budget.
          rate_limit to: Spree::Api::Config[:rate_limit_login],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache, only: :create, name: 'seller_login',
                     with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_login]) }
          rate_limit to: Spree::Api::Config[:rate_limit_refresh],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache, only: :providers, name: 'seller_providers',
                     with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }
          rate_limit to: Spree::Api::Config[:rate_limit_refresh],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache, only: [:refresh, :logout], name: 'seller_refresh',
                     with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }

          # Signing in is what establishes which sellers the caller may act as,
          # so these actions run before any seller is known.
          skip_before_action :set_current_seller_context, only: [:create, :refresh, :logout, :providers]
          skip_before_action :authenticate_seller!, only: [:create, :refresh, :logout, :providers]

          # POST /api/v3/seller/auth/login
          def create
            strategy = authentication_strategy
            return unless strategy

            result = strategy.authenticate
            return render_authentication_failed(result.error) unless result.success?

            user = result.value
            # A store's own staff share this user class, so authenticating is
            # not enough: without a role on some seller there is no panel to
            # sign in to, and minting a token would hand out an audience the
            # holder can do nothing with.
            return render_authentication_failed(Spree.t(:seller_membership_required)) unless user.seller_member?

            set_refresh_cookie(
              Spree::RefreshToken.create_for(
                user,
                audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER,
                request_env: request_env_for_token
              )
            )
            render json: auth_response(user)
          end

          # GET /api/v3/seller/auth/providers
          def providers
            render json: { providers: Spree.seller_authentication_strategies.describe }
          end

          # POST /api/v3/seller/auth/refresh
          def refresh
            refresh_token_value = refresh_token_from_cookie

            if refresh_token_value.blank?
              return render_error(
                code: ErrorHandler::ERROR_CODES[:invalid_refresh_token],
                message: 'Refresh token cookie missing',
                status: :unauthorized
              )
            end

            # Narrowed by audience: a token minted on another surface must not
            # be exchangeable for a seller one.
            refresh_token = Spree::RefreshToken.active.
                            for_audience(Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER).
                            find_by(token: refresh_token_value)

            if refresh_token.nil?
              clear_refresh_cookie
              return render_error(
                code: ErrorHandler::ERROR_CODES[:invalid_refresh_token],
                message: 'Invalid or expired refresh token',
                status: :unauthorized
              )
            end

            user = refresh_token.user
            # Membership can be revoked while a session is live; the refresh is
            # where that takes effect.
            unless user.seller_member?
              refresh_token.destroy
              clear_refresh_cookie
              return render_error(
                code: ErrorHandler::ERROR_CODES[:access_denied],
                message: Spree.t(:seller_membership_required),
                status: :forbidden
              )
            end

            set_refresh_cookie(refresh_token.rotate!(request_env: request_env_for_token))
            render json: auth_response(user)
          end

          # POST /api/v3/seller/auth/logout
          def logout
            refresh_token_value = refresh_token_from_cookie

            if refresh_token_value.present?
              Spree::RefreshToken.
                for_audience(Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER).
                find_by(token: refresh_token_value)&.destroy
            end

            clear_refresh_cookie
            head :no_content
          end

          private

          def render_authentication_failed(message)
            render_error(
              code: ErrorHandler::ERROR_CODES[:authentication_failed],
              message: message,
              status: :unauthorized
            )
          end

          def auth_response(user)
            {
              token: generate_jwt(user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER),
              user: Spree.api.seller_team_member_serializer.new(user, params: { store: user.sellers.first&.store }).to_h,
              sellers: serialized_sellers(user)
            }
          end

          # The panel needs these to choose an X-Spree-Seller-Id before it can
          # make any other request.
          def serialized_sellers(user)
            user.sellers.map { |seller| { id: seller.prefixed_id, name: seller.name, status: seller.status } }
          end

          def authentication_strategies
            Spree.seller_authentication_strategies
          end

          def authentication_user_class
            Spree.admin_user_class
          end

          def jwt_expiration
            Spree::Api::Config[:admin_jwt_expiration]
          end

          def request_env_for_token
            { ip_address: request.remote_ip, user_agent: request.user_agent&.truncate(255) }
          end
        end
      end
    end
  end
end
