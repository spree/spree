module Spree
  module Api
    module V2
      module Platform
        class AddressesController < ResourceController
          private

          def model_class
            Spree::Address
          end

          def scope_includes
            [:country, :state, :user]
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_address_serializer.constantize
          end
        end
      end
    end
  end
end
