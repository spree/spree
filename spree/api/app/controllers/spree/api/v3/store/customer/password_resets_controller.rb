# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Store
        module Customer
          class PasswordResetsController < Store::BaseController
            rate_limit to: Spree::Api::Config[:rate_limit_password_reset],
                       within: Spree::Api::Config[:rate_limit_window].seconds,
                       store: Rails.cache,
                       with: RATE_LIMIT_RESPONSE

            skip_before_action :authenticate_user

            # POST /api/v3/store/customer/password_resets
            def create
              redirect_url = params[:redirect_url]

              # Validate redirect_url against allowed origins (secure by default).
              # If no allowed origins are configured, redirect_url is silently ignored
              # to prevent open redirect / token exfiltration attacks.
              if redirect_url.present?
                if current_store.allowed_origins.exists? && current_store.allowed_origin?(redirect_url)
                  # redirect_url is valid — keep it
                else
                  redirect_url = nil
                end
              end

              user = Spree.user_class.find_by(email: params[:email])

              if user
                token = user.generate_token_for(:password_reset)
                event_payload = { reset_token: token, email: user.email }
                event_payload[:redirect_url] = redirect_url if redirect_url.present?
                user.publish_event('customer.password_reset_requested', event_payload)
              end

              # Always return 202 to prevent email enumeration
              render json: { message: Spree.t(:password_reset_requested, scope: :api) }, status: :accepted
            end

            # PATCH /api/v3/store/customer/password_resets/:id
            def update
              user = Spree.user_class.find_by_password_reset_token(params[:id])

              unless user
                return render_error(
                  code: ERROR_CODES[:password_reset_token_invalid],
                  message: Spree.t(:password_reset_token_invalid, scope: :api),
                  status: :unprocessable_content
                )
              end

              if user.update(password: params[:password], password_confirmation: params[:password_confirmation])
                jwt = generate_jwt(user)
                user.publish_event('customer.password_reset')

                render json: {
                  token: jwt,
                  user: serializer_class.new(user, params: serializer_params).to_h
                }
              else
                render_errors(user.errors)
              end
            end

            protected

            def serializer_class
              Spree.api.customer_serializer
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
          end
        end
      end
    end
  end
end
