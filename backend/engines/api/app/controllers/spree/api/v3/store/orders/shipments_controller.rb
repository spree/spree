module Spree
  module Api
    module V3
      module Store
        module Orders
          class ShipmentsController < ResourceController
            include Spree::Api::V3::OrderConcern

            before_action :authorize_order_access!
            skip_before_action :set_resource
            before_action :set_shipment, only: [:show, :update]

            # PATCH /api/v3/store/orders/:order_id/shipments/:id
            def update
              if permitted_params[:selected_shipping_rate_id].present?
                shipping_rate = @resource.shipping_rates.find_by_prefix_id!(permitted_params[:selected_shipping_rate_id])
                @resource.selected_shipping_rate_id = shipping_rate.id
                @resource.save!
              end

              render_order
            end

            protected

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
              params.permit(:selected_shipping_rate_id)
            end

            private

            # Find shipment without additional authorization - order access already verified
            def set_shipment
              @resource = scope.find_by_prefix_id!(params[:id])
            end
          end
        end
      end
    end
  end
end
