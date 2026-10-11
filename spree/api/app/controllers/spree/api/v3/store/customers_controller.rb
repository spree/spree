module Spree
  module Api
    module V3
      module Store
        class CustomersController < Store::BaseController
          include Spree::Api::V3::CurrentPasswordConfirmation

          allow_guest_storefront_access!
          rate_limit to: Spree::Api::Config[:rate_limit_register], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :create, with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_register]) }

          skip_before_action :authenticate_user, only: [:create]
          prepend_before_action :require_authentication!, only: [:show, :update]

          CUSTOMER_FIELDS = Spree::Api::V3::RequestSchema.new do
            string :first_name, example: 'John'
            string :last_name, example: 'Doe'
            string :phone, example: '+1 555 123 4567'
            boolean :accepts_email_marketing
            object :metadata, description: 'Write-only key-value metadata.'
          end

          request_params 'RegisterParams', action: :create do
            string :email, required: true, format: :email, example: 'newuser@example.com'
            string :password, required: true, example: 'password123'
            string :password_confirmation, example: 'password123'
            include_fields CUSTOMER_FIELDS
            boolean :terms_of_service, permit: false,
                                       description: "Whether the customer ticked the storefront's terms of service box. Recorded as their consent."
          end

          request_params 'UpdateCustomerParams', action: :update do
            string :email, format: :email, example: 'customer@example.com'
            string :password, :password_confirmation
            string :current_password, description: 'Required when changing the email or the password.'
            include_fields CUSTOMER_FIELDS
          end

          # POST /api/v3/store/customers
          # Registration runs through the customer_create_workflow seam
          # (password requirement, newsletter-subscriber linking, registration
          # policy hooks); token issuance is an HTTP session concern and
          # stays here.
          def create
            result = Spree.customer_create_workflow.call(
              store: current_store,
              # Records that the storefront's terms box was ticked. Read from
              # params rather than permitted: it is evidence the workflow acts
              # on, not an attribute of the customer row.
              terms_of_service: params[:terms_of_service],
              # Where and from what the agreement was made. A consent record
              # without them says only that someone ticked a box.
              ip_address: request.remote_ip,
              user_agent: request.user_agent,
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
            return render_current_password_invalid if sensitive_update? && !valid_current_password?

            update_params = permitted_params.except(:current_password)
            current_user.consent_source = Spree::ConsentRecord::ACCOUNT

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
              hide_prices: hide_prices?
            }
          end

          def permitted_params
            params.permit(*declared_permitted_attributes)
          end

          private

          def sensitive_update?
            (params[:email].present? && params[:email] != current_user.email) ||
              params[:password].present?
          end

          def user_serializer
            Spree.api.customer_serializer
          end
        end
      end
    end
  end
end
