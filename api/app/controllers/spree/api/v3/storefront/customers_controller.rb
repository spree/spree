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
            serializer_class.new(resource, params: serializer_params).to_h
          end

          def serializer_class
            Spree.api.v3_storefront_user_serializer
          end

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              includes: include_tree
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
