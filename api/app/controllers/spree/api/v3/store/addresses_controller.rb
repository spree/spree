module Spree
  module Api
    module V3
      module Store
        class AddressesController < Store::ResourceController
          prepend_before_action :require_authentication!

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
            params.require(:address).permit(Spree::PermittedAttributes.address_attributes)
          end
        end
      end
    end
  end
end
