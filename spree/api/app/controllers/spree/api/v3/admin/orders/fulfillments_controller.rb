module Spree
  module Api
    module V3
      module Admin
        module Orders
          class FulfillmentsController < BaseController
            scoped_resource :fulfillments

            before_action :set_resource, only: [:show, :update, :fulfill, :cancel, :resume, :split]

            # POST /api/v3/admin/orders/:order_id/fulfillments
            #
            # Manually registers a fulfillment on a completed order (external
            # carrier / 3PL sync), bypassing order routing. Moves the requested
            # line item quantities out of their routed fulfillments; when
            # `items` is omitted, everything not yet shipped is moved. An
            # explicit `cost` persists only with `status: 'shipped'` — pending
            # fulfillments are re-priced by the rate engine.
            def create
              authorize!(:create, Spree::Shipment)

              with_order_lock do
                result = Spree.fulfillment_create_service.call(
                  order: @order,
                  stock_location: stock_location_for_create,
                  items: items_for_create,
                  tracking: create_params[:tracking],
                  delivery_method: delivery_method_for_create,
                  cost: create_params[:cost],
                  status: create_params[:status],
                  metadata: create_params[:metadata]&.to_h
                )

                if result.success?
                  render json: serialize_resource(result.value), status: :created
                else
                  render_result_error(result)
                end
              end
            end

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
                                   find_stock_location!(params[:stock_location_id])
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
              params.permit(:tracking, :selected_delivery_rate_id, :stock_location_id)
            end

            def create_params
              @create_params ||= params.permit(:stock_location_id, :tracking, :delivery_method_id, :cost, :status, metadata: {}, items: [:item_id, :quantity])
            end

            def find_stock_location!(id)
              Spree::StockLocation.accessible_by(current_ability, :show).find_by_prefix_id!(id)
            end

            def stock_location_for_create
              find_stock_location!(create_params.require(:stock_location_id))
            end

            def delivery_method_for_create
              return if create_params[:delivery_method_id].blank?

              Spree::ShippingMethod.accessible_by(current_ability, :show).find_by_prefix_id!(create_params[:delivery_method_id])
            end

            def items_for_create
              return if create_params[:items].nil?

              create_params[:items].map do |item|
                {
                  line_item: @order.line_items.find_by_prefix_id!(item[:item_id]),
                  quantity: Integer(item[:quantity].to_s, exception: false)
                }
              end
            end
          end
        end
      end
    end
  end
end
