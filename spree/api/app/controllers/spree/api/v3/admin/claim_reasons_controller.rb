module Spree
  module Api
    module V3
      module Admin
        class ClaimReasonsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::ClaimReason
          end

          def serializer_class
            Spree.api.admin_claim_reason_serializer
          end

          def permitted_params
            params.permit(:name, :active)
          end
        end
      end
    end
  end
end
