module Spree
  module Api
    module V2
      module Platform
        class AdjustmentsController < ResourceController
          private

          def model_class
            Spree::Adjustment
          end

          def scope_includes
            [:order, :adjustable]
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_adjustment_serializer.constantize
          end
        end
      end
    end
  end
end
