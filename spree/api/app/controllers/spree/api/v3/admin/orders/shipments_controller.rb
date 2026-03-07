module Spree
  module Api
    module V3
      module Admin
        module Orders
          class ShipmentsController < BaseController
            before_action :set_resource, only: [:show, :update, :ship, :cancel, :resume, :split]

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
                @resource.ship!
                render json: serialize_resource(@resource.reload)
              rescue StateMachines::InvalidTransition => e
                render_service_error(e.message)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/shipments/:id/cancel
            def cancel
              with_order_lock do
                @resource.cancel!
                render json: serialize_resource(@resource.reload)
              rescue StateMachines::InvalidTransition => e
                render_service_error(e.message)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/shipments/:id/resume
            def resume
              with_order_lock do
                @resource.resume!
                render json: serialize_resource(@resource.reload)
              rescue StateMachines::InvalidTransition => e
                render_service_error(e.message)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/shipments/:id/split
            def split
              with_order_lock do
                variant = Spree::Variant.find_by_prefix_id!(params[:variant_id])
                quantity = params[:quantity].to_i

                stock_location = if params[:stock_location_id].present?
                                   Spree::StockLocation.find_by_prefix_id!(params[:stock_location_id])
                                 else
                                   @resource.stock_location
                                 end

                fulfilment_changer = @resource.transfer_to_location(variant, quantity, stock_location)

                if fulfilment_changer.run!
                  # Original shipment may be destroyed if all items were transferred
                  shipments = @order.reload.shipments
                  render json: {
                    data: shipments.map { |s| serialize_resource(s) }
                  }
                else
                  render_validation_error(fulfilment_changer.errors)
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

            def permitted_params
              params.permit(*Spree::PermittedAttributes.shipment_attributes - [:id])
            end
          end
        end
      end
    end
  end
end
