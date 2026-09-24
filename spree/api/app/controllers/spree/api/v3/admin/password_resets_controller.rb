# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class PasswordResetsController < Admin::BaseController
          include Spree::Api::V3::Admin::AuthCookies

          skip_scope_check!
          rate_limit to: Spree::Api::Config[:rate_limit_password_reset],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     with: RATE_LIMIT_RESPONSE

          skip_before_action :authenticate_admin!

          # POST /api/v3/admin/password_resets
          def create
            user = Spree.admin_user_class.find_by(email: params[:email])

            if user
              redirect_url = trusted_redirect_url(user)
              token = user.generate_token_for(:password_reset)
              event_payload = { reset_token: token, email: user.email, store_id: current_store.prefixed_id }
              event_payload[:redirect_url] = redirect_url if redirect_url.present?
              user.publish_event('admin_user.password_reset_requested', event_payload)
            end

            # Always return 202 to prevent email enumeration
            render json: { message: Spree.t(:password_reset_requested, scope: :api) }, status: :accepted
          end

          # PATCH /api/v3/admin/password_resets/:id
          def update
            user = Spree.admin_user_class.find_by_password_reset_token(params[:id])

            unless user
              return render_error(
                code: ERROR_CODES[:password_reset_token_invalid],
                message: Spree.t(:password_reset_token_invalid, scope: :api),
                status: :unprocessable_content
              )
            end

            if user.update(password: params[:password], password_confirmation: params[:password_confirmation])
              user.publish_event('admin_user.password_reset')
              # A password reset must kill every existing session — a stolen
              # refresh token must not survive the victim resetting their
              # password. Revoke first, then mint the fresh token for this
              # browser (the auto-sign-in below).
              Spree::RefreshToken.revoke_all_for(user)
              refresh_token = Spree::RefreshToken.create_for(user, audience: JWT_AUDIENCE_ADMIN, request_env: request_env_for_token)
              set_refresh_cookie(refresh_token)

              render json: auth_response(user)
            else
              render_errors(user.errors)
            end
          end

          private

          # The emailed link carries the reset token, so it may only point at
          # the dashboard — never at a storefront origin, which anyone who can
          # edit a store's allowed origins could add — and only when the
          # account belongs to the store the request names. Anything else is
          # ignored and the email links to the dashboard's own reset page.
          #
          # @return [String, nil]
          def trusted_redirect_url(user)
            redirect_url = params[:redirect_url].presence
            return if redirect_url.blank?
            return unless same_origin?(redirect_url, Spree::Stores::DashboardUrl.call(store: current_store))
            return unless staff_of_current_store?(user)

            redirect_url
          end

          def same_origin?(url, other)
            first = URI.parse(url.to_s)
            second = URI.parse(other.to_s)
            first.host.present? && [first.scheme, first.host, first.port] == [second.scheme, second.host, second.port]
          rescue URI::InvalidURIError
            false
          end

          def staff_of_current_store?(user)
            return false unless user.respond_to?(:spree_roles)

            user.spree_roles.for_resource(current_store).exists?
          end

          def auth_response(user)
            {
              token: generate_jwt(user, audience: JWT_AUDIENCE_ADMIN),
              user: admin_user_serializer.new(user, params: serializer_params).to_h
            }
          end

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              currency: current_currency,
              user: nil,
              includes: []
            }
          end

          def admin_user_serializer
            Spree.api.admin_admin_user_serializer
          end

          def request_env_for_token
            {
              ip_address: request.remote_ip,
              user_agent: request.user_agent&.truncate(255)
            }
          end
        end
      end
    end
  end
end
