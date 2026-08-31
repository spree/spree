module Spree
  module Api
    module V3
      module Store
        class CustomersController < Store::BaseController
          allow_guest_storefront_access!
          rate_limit to: Spree::Api::Config[:rate_limit_register], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :create, with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_register]) }

          skip_before_action :authenticate_user, only: [:create]
          prepend_before_action :require_authentication!, only: [:show, :update]

          # POST /api/v3/store/customers
          # Registration runs through the customer_create_workflow seam
          # (password requirement, newsletter-subscriber linking, registration
          # policy hooks); token issuance is an HTTP session concern and
          # stays here.
          def create
            result = Spree.customer_create_workflow.call(
              store: current_store,
              **permitted_params.except(:current_password).to_h.symbolize_keys
            )

            if result.success?
              user = result.value
              refresh_token = Spree::RefreshToken.create_for(user, audience: JWT_AUDIENCE_STORE, request_env: {
                ip_address: request.remote_ip,
                user_agent: request.user_agent&.truncate(255)
              })
              render json: {
                token: generate_jwt(user),
                refresh_token: refresh_token.token,
                user: user_serializer.new(user, params: serializer_params).to_h
              }, status: :created
            else
              render_result_error(result)
            end
          end

          # GET /api/v3/store/customer
          def show
            render json: serialize_resource(current_user)
          end

          # PATCH /api/v3/store/customer
          def update
            if sensitive_update? && !valid_current_password?
              return render_error(
                code: ErrorHandler::ERROR_CODES[:current_password_invalid],
                message: Spree.t(:current_password_invalid, scope: :api),
                status: :unprocessable_content
              )
            end

            update_params = permitted_params.except(:current_password)

            if current_user.update(update_params)
              render json: serialize_resource(current_user)
            else
              render_errors(current_user.errors)
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
              user: current_user,
              includes: [],
              hide_prices: hide_prices?,
              pricing_access: pricing_access
            }
          end

          def permitted_params
            params.permit(:email, :password, :password_confirmation, :first_name, :last_name,
                          :accepts_email_marketing, :phone, :current_password, metadata: {})
          end

          private

          def sensitive_update?
            (params[:email].present? && params[:email] != current_user.email) ||
              params[:password].present?
          end

          def valid_current_password?
            return false if params[:current_password].blank?

            if current_user.respond_to?(:valid_password?)
              current_user.valid_password?(params[:current_password])
            elsif current_user.respond_to?(:authenticate)
              current_user.authenticate(params[:current_password]).present?
            else
              false
            end
          end

          def user_serializer
            Spree.api.customer_serializer
          end
        end
      end
    end
  end
end
