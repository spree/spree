module Spree
  module Api
    module V3
      module Store
        class ShipmentsController < ResourceController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!

          protected

          def scope
            @order.shipments
          end

          def model_class
            Spree::Shipment
          end

          def serializer_class
            Spree.api.v3_store_shipment_serializer
          end

          def permitted_params
            params.require(:shipment).permit(:selected_shipping_rate_id)
          end
        end
      end
    end
  end
end
