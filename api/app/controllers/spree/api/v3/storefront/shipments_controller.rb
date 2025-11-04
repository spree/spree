module Spree
  module Api
    module V3
      module Storefront
        class ShipmentsController < ResourceController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!
          before_action :set_shipment, only: [:show, :update]

          # GET /api/v3/storefront/orders/:order_id/shipments
          def index
            render json: {
              data: serialize_collection(@order.shipments)
            }
          end

          # GET /api/v3/storefront/orders/:order_id/shipments/:id
          def show
            render json: serialize_resource(@shipment)
          end

          # PATCH /api/v3/storefront/orders/:order_id/shipments/:id
          def update
            if permitted_params[:selected_shipping_rate_id].present?
              @shipment.selected_shipping_rate_id = permitted_params[:selected_shipping_rate_id]
              @shipment.save
            end

            render json: serialize_resource(@shipment)
          end

          protected

          def set_shipment
            @shipment = @order.shipments.find(params[:id])
          end

          def model_class
            Spree::Shipment
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_shipment_serializer.constantize
          end

          def permitted_params
            params.require(:shipment).permit(Spree::PermittedAttributes.shipment_attributes)
          end
        end
      end
    end
  end
end
