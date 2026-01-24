module Spree
  module Api
    module V3
      module Store
        class ShipmentsController < Store::ResourceController
          include Spree::Api::V3::OrderConcern

          before_action :authorize_order_access!

          protected

          def set_parent
            @parent = current_store.orders.friendly.find(params[:order_id])
          end

          def parent_association
            :shipments
          end

          def model_class
            Spree::Shipment
          end

          def serializer_class
            Spree.api.shipment_serializer
          end

          def permitted_params
            params.require(:shipment).permit(:selected_shipping_rate_id)
          end
        end
      end
    end
  end
end
