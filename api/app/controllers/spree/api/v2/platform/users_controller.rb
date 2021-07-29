module Spree
  module Api
    module V2
      module Platform
        class UsersController < ResourceController
          private

          def model_class
            Spree.user_class
          end

          def resource_serializer
            Spree::Api::V2::Platform::UserSerializer
          end

          def scope_includes
            [:ship_address, :bill_address]
          end
        end
      end
    end
  end
end
