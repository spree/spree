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
            Spree.api.platform_adjustment_serializer
          end
        end
      end
    end
  end
end
