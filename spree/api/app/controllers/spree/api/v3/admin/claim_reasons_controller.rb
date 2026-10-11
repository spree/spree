module Spree
  module Api
    module V3
      module Admin
        class ClaimReasonsController < ResourceController
          scoped_resource :settings

          request_params :reason do
            string :name, required: :create
            boolean :active, description: 'Whether the reason is offered on new records.'
          end

          protected

          def model_class
            Spree::ClaimReason
          end

          def serializer_class
            Spree.api.admin_claim_reason_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
