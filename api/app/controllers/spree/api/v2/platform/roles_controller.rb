module Spree
  module Api
    module V2
      module Platform
        class RolesController < ResourceController
          private

          def model_class
            Spree::Role
          end
        end
      end
    end
  end
end
