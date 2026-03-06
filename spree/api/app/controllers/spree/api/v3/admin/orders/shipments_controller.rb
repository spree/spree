module Spree
  module Api
    module V3
      module Admin
        module Orders
          class ShipmentsController < ResourceController
            include Spree::Api::V3::OrderLock

            before_action :authorize_order_access!
            skip_before_action :set_resource, only: [:index]
            before_action :set_shipment, only: [:show, :update, :ship]

            # PATCH /api/v3/admin/orders/:order_id/shipments/:id
            def update
              with_order_lock do
                result = Spree.shipment_update_service.call(
                  shipment: @resource,
                  shipment_attributes: permitted_params.to_h
                )

                if result.success?
                  render json: serialize_resource(@resource.reload)
                else
                  render_result_error(result)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/shipments/:id/ship
            def ship
              with_order_lock do
                result = Spree.shipment_change_state_service.call(
                  shipment: @resource,
                  state: 'ship'
                )

                if result.success?
                  render json: serialize_resource(@resource.reload)
                else
                  render_service_error(result.error)
                end
              end
            end

            protected

            def model_class
              Spree::Shipment
            end

            def serializer_class
              Spree.api.admin_shipment_serializer
            end

            def parent_association
              :shipments
            end

            def set_parent
              @parent = current_store.orders.find_by_prefix_id!(params[:order_id])
              @order = @parent
            end

            def authorize_order_access!
              authorize!(:show, @parent)
            end

            def set_shipment
              @resource = @parent.shipments.find_by_prefix_id!(params[:id])
              authorize_resource!(@resource)
            end

            def permitted_params
              params.permit(:tracking, :selected_shipping_rate_id, :stock_location_id)
            end

            private

            def render_result_error(result)
              error = result.error
              errors = error.respond_to?(:value) ? error.value : error

              if errors.is_a?(ActiveModel::Errors)
                render_validation_error(errors)
              else
                render_service_error(error)
              end
            end
          end
        end
      end
    end
  end
end
