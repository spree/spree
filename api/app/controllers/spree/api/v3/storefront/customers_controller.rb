module Spree
  module Api
    module V3
      module Storefront
        class CustomersController < BaseController
          before_action :require_authentication!

          # GET /api/v3/storefront/customers/me
          def show
            render json: serialize_resource(current_user)
          end

          # PATCH /api/v3/storefront/customers/me
          def update
            if current_user.update(customer_params)
              render json: serialize_resource(current_user)
            else
              render_errors(current_user.errors)
            end
          end

          protected

          def serialize_resource(resource)
            serializer_class.new(resource, serializer_context).as_json
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_user_serializer.constantize
          end

          def serializer_context
            {
              store: current_store,
              locale: current_locale,
              includes: requested_includes
            }
          end

          def customer_params
            params.require(:customer).permit(Spree::PermittedAttributes.user_attributes)
          end
        end
      end
    end
  end
end
