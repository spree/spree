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
        end
      end
    end
  end
end
