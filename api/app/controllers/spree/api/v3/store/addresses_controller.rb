module Spree
  module Api
    module V3
      module Store
        class AddressesController < Store::ResourceController
          prepend_before_action :require_authentication!

          # POST /api/v3/store/customers/me/addresses
          def create
            result = Spree.address_create_service.call(
              address_params: permitted_params,
              user: current_user
            )

            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_errors(result.value.errors)
            end
          end

          # PATCH /api/v3/store/customers/me/addresses/:id
          def update
            result = Spree.address_update_service.call(
              address: @resource,
              address_params: permitted_params
            )

            if result.success?
              render json: serialize_resource(result.value)
            else
              render_errors(result.value.errors)
            end
          end

          protected

          def set_parent
            @parent = current_user
          end

          def parent_association
            :addresses
          end

          def model_class
            Spree::Address
          end

          def serializer_class
            Spree.api.address_serializer
          end

          def permitted_params
            params.require(:address).permit(
              :firstname, :lastname, :address1, :address2, :city,
              :zipcode, :phone, :company, :country_iso, :state_code
            )
          end
        end
      end
    end
  end
end
