module Spree
  module Api
    module V3
      module Store
        module Customer
          class AccountController < Store::BaseController
            prepend_before_action :require_authentication!

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
          end
        end
      end
    end
  end
end
