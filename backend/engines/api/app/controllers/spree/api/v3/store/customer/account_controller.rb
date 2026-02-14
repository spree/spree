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
              if current_user.update(permitted_params)
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
                            :accepts_email_marketing, :phone)
            end
          end
        end
      end
    end
  end
end
