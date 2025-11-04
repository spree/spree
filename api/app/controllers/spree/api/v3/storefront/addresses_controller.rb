module Spree
  module Api
    module V3
      module Storefront
        class AddressesController < ResourceController
          before_action :require_authentication!

          protected

          def scope
            current_user.addresses
          end

          def model_class
            Spree::Address
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_address_serializer.constantize
          end

          def permitted_params
            params.require(:address).permit(Spree::PermittedAttributes.address_attributes)
          end
        end
      end
    end
  end
end
