module Spree
  module Api
    module V3
      module Admin
        module Orders
          class FulfillmentsController < BaseController
            scoped_resource :fulfillments

            before_action :set_resource, only: [:show, :update, :fulfill, :cancel, :resume, :split]

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id
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

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/fulfill
            def fulfill
              with_order_lock do
                @resource.ship!
                render json: serialize_resource(@resource.reload)
              rescue StateMachines::InvalidTransition => e
                render_service_error(e.message)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/cancel
            def cancel
              with_order_lock do
                @resource.cancel!
                render json: serialize_resource(@resource.reload)
              rescue StateMachines::InvalidTransition => e
                render_service_error(e.message)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/resume
            def resume
              with_order_lock do
                @resource.resume!
                render json: serialize_resource(@resource.reload)
              rescue StateMachines::InvalidTransition => e
                render_service_error(e.message)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/split
            def split
              with_order_lock do
                variant = current_store.variants.find_by_prefix_id!(params[:variant_id])
                quantity = params[:quantity].to_i

                stock_location = if params[:stock_location_id].present?
                                   Spree::StockLocation.accessible_by(current_ability, :show).find_by_prefix_id!(params[:stock_location_id])
                                 else
                                   @resource.stock_location
                                 end

                fulfilment_changer = @resource.transfer_to_location(variant, quantity, stock_location)

                if fulfilment_changer.run!
                  fulfillments = @order.reload.shipments
                  render json: {
                    data: fulfillments.map { |s| serialize_resource(s) }
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
              Spree.api.admin_fulfillment_serializer
            end

            def parent_association
              :shipments
            end

            # State changes go through the dedicated `fulfill`/`cancel`/`resume`
            # member actions, not mass assignment.
            def permitted_params
              params.permit(:tracking, :selected_shipping_rate_id, :stock_location_id)
            end
          end
        end
      end
    end
  end
end
