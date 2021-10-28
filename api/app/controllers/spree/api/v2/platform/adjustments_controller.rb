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
            Spree::Api::V2::Platform::AdjustmentSerializer
          end
        end
      end
    end
  end
end
