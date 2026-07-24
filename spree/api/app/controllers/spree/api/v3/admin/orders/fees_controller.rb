module Spree
  module Api
    module V3
      module Admin
        module Orders
          class FeesController < BaseController
            protected

            def model_class
              Spree::Fee
            end

            def serializer_class
              Spree.api.admin_fee_serializer
            end

            def parent_association
              :fees
            end
          end
        end
      end
    end
  end
end
