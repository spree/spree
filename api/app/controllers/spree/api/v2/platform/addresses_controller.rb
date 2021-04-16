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
        end
      end
    end
  end
end
