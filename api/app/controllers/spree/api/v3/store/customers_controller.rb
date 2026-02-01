module Spree
  module Api
    module V3
      module Store
        class CustomersController < Store::BaseController
          prepend_before_action :require_authentication!

          # GET  /api/v3/store/customers/me
          def show
            render json: serialize_resource(current_user)
          end

          # PATCH  /api/v3/store/customers/me
          def update
            if current_user.update(permitted_params)
              render json: serialize_resource(current_user)
            else
              render_errors(current_user.errors)
            end
          end

          protected

          def serializer_class
            Spree.api.user_serializer
          end

          def permitted_params
            params.require(:user).permit(Spree::PermittedAttributes.user_attributes)
          end
        end
      end
    end
  end
end
