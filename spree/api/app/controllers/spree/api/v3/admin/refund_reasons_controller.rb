module Spree
  module Api
    module V3
      module Admin
        class RefundReasonsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::RefundReason
          end

          def serializer_class
            Spree.api.admin_refund_reason_serializer
          end

          def permitted_params
            params.permit(:name, :active)
          end
        end
      end
    end
  end
end
