module Spree
  module Api
    module V3
      module Admin
        module Orders
          class AdjustmentsController < BaseController
            protected

            def model_class
              Spree::Adjustment
            end

            def serializer_class
              Spree.api.admin_adjustment_serializer
            end

            def parent_association
              :adjustments
            end
          end
        end
      end
    end
  end
end
