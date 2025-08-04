module Spree
  module Api
    module V2
      module Platform
        class RolesController < ResourceController
          private

          def model_class
            Spree::Role
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_role_serializer.constantize
          end
        end
      end
    end
  end
end
