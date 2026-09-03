module Spree
  module Api
    module V3
      module Seller
        # Why goods come back.
        class ReturnReasonsController < ReasonsController
          protected

          def model_class
            Spree::ReturnReason
          end

          def reasons_association
            :return_reasons
          end
        end
      end
    end
  end
end
