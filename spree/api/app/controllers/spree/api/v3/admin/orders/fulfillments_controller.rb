module Spree
  module Api
    module V3
      module Admin
        module Orders
          class FulfillmentsController < BaseController
            scoped_resource :fulfillments

            before_action :set_resource, only: [:show, :update, :fulfill, :mark_delivered, :cancel, :resume, :split]

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
                result = Spree.fulfillment_create_workflow.call(
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
                result = Spree.fulfillment_update_workflow.call(
                  fulfillment: @resource,
                  fulfillment_attributes: permitted_params.to_h
                )

                if result.success?
                  render json: serialize_resource(@resource.reload)
                else
                  render_result_error(result)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/fulfill
            #
            # Marks the fulfillment as fulfilled. Passing `items` ships only
            # those quantities: they are split into a new fulfillment which is
            # the one that ships and is returned, leaving the remainder open.
            def fulfill
              with_order_lock do
                result = Spree.fulfillment_fulfill_workflow.call(
                  fulfillment: @resource,
                  items: items_for_fulfill,
                  tracking: fulfill_params[:tracking],
                  notify_customer: notify_customer?(fulfill_params[:notify_customer]),
                  force: ActiveModel::Type::Boolean.new.cast(fulfill_params[:force]).present?
                )

                if result.success?
                  render json: serialize_resource(result.value)
                else
                  render_result_error(result)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/mark_delivered
            #
            # Confirms the customer received the goods. Staff can record this
            # by hand — a merchant with no carrier integration still needs a
            # delivered state.
            def mark_delivered
              with_order_lock do
                result = Spree.fulfillment_mark_delivered_workflow.call(
                  fulfillment: @resource,
                  delivered_at: mark_delivered_params[:delivered_at],
                  notify_customer: notify_customer?(mark_delivered_params[:notify_customer])
                )

                if result.success?
                  render json: serialize_resource(result.value)
                else
                  render_result_error(result)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/cancel
            def cancel
              with_order_lock do
                result = Spree.fulfillment_cancel_workflow.call(fulfillment: @resource)

                if result.success?
                  render json: serialize_resource(result.value)
                else
                  render_result_error(result)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/resume
            def resume
              with_order_lock do
                result = Spree.fulfillment_resume_workflow.call(fulfillment: @resource)

                if result.success?
                  render json: serialize_resource(result.value)
                else
                  render_result_error(result)
                end
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
                  fulfillments = @order.reload.fulfillments
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

            def fulfill_params
              @fulfill_params ||= params.permit(:tracking, :notify_customer, :force, items: [:item_id, :quantity])
            end

            def mark_delivered_params
              @mark_delivered_params ||= params.permit(:delivered_at, :notify_customer)
            end

            # Only an explicit false suppresses the email — an omitted flag, and
            # anything unparseable, keeps the historic behavior of sending it.
            def notify_customer?(value)
              !ActiveModel::Type::Boolean.new.cast(value).equal?(false)
            end

            def items_for_fulfill
              return if fulfill_params[:items].nil?

              fulfill_params[:items].map do |item|
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
