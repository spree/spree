module Spree
  module Api
    module V3
      module Seller
        # What went wrong with a delivery.
        class ClaimReasonsController < ReasonsController
          protected

          def model_class
            Spree::ClaimReason
          end

          def reasons_association
            :claim_reasons
          end
        end
      end
    end
  end
end
