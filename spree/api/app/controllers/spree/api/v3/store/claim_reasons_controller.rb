module Spree
  module Api
    module V3
      module Store
        # What went wrong with a delivery — offered when filing a claim.
        class ClaimReasonsController < ReasonsController
          protected

          def model_class
            Spree::ClaimReason
          end

          def serializer_class
            Spree.api.claim_reason_serializer
          end
        end
      end
    end
  end
end
