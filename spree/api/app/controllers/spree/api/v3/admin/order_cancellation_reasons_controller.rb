module Spree
  module Api
    module V3
      module Admin
        class OrderCancellationReasonsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::OrderCancellationReason
          end

          def serializer_class
            Spree.api.admin_order_cancellation_reason_serializer
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :name, :active)
          end
        end
      end
    end
  end
end
