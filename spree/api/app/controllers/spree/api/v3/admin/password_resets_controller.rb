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
            redirect_url = params[:redirect_url]

            # Validate redirect_url against allowed origins (secure by default).
            # If no allowed origins are configured, redirect_url is silently ignored
            # to prevent open redirect / token exfiltration attacks.
            if redirect_url.present?
              unless current_store.allowed_origins.exists? && current_store.allowed_origin?(redirect_url)
                redirect_url = nil
              end
            end

            user = Spree.admin_user_class.find_by(email: params[:email])

            if user
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
              refresh_token = Spree::RefreshToken.create_for(user, request_env: request_env_for_token)
              set_refresh_cookie(refresh_token)

              render json: auth_response(user)
            else
              render_errors(user.errors)
            end
          end

          private

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
