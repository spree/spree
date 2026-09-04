module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Dispatching what a seller owes on one of their orders.
          #
          # Rooted at the order fetched through `current_seller_orders`, so a
          # fulfillment on somebody else's order reads as missing rather than
          # denied — and a seller can never ship against an order that is not
          # theirs, whatever id they send.
          #
          # Fulfilling reuses the operator's workflow, so the customer email,
          # the label purchase and the extension hooks all happen exactly as
          # they do when the marketplace ships on the seller's behalf.
          class FulfillmentsController < Seller::BaseController
            include Spree::Api::V3::OrderLock

            scoped_resource :fulfillments

            before_action :set_order
            before_action :set_fulfillment,
                          only: [:show, :update, :fulfill, :cancel, :split]

            def index
              # This action builds its own collection rather than going through
              # the base controller, so it preloads what the serializer reads —
              # otherwise every parcel costs a query for its consignments and
              # another for its labels.
              fulfillments = @order.fulfillments.
                             includes(:deliveries, :shipping_labels, :fulfillment_items).
                             preload_associations_lazily

              render json: { data: fulfillments.map { |fulfillment| serialize(fulfillment) } }
            end

            def show
              render json: serialize(@fulfillment)
            end

            # PATCH /api/v3/seller/orders/:order_id/fulfillments/:id/fulfill
            #
            # Ships the parcel. `items` narrows it to part of what the
            # fulfillment holds, which splits the rest onto a new one.
            def fulfill
              with_order_lock do
                result = Spree.fulfillment_fulfill_workflow.call(
                  fulfillment: @fulfillment,
                  items: items_for_fulfill,
                  tracking: fulfill_params[:tracking],
                  tracking_carrier: fulfill_params[:tracking_carrier],
                  notify_customer: notify_customer?(fulfill_params[:notify_customer])
                )

                if result.success?
                  render json: serialize(result.value)
                else
                  render_service_error(@fulfillment.errors.presence || result.error)
                end
              end
            end

            # PATCH /api/v3/seller/orders/:order_id/fulfillments/:id
            #
            # The tracking pair, and which of the seller's own shelves the
            # parcel ships from — a seller who picks from a different warehouse
            # than the split assumed needs to say so, and the rate is requoted
            # from there.
            #
            # The origin is resolved through `current_seller.stock_locations`,
            # so a marketplace warehouse is unreachable however the id arrives.
            def update
              with_order_lock do
                render_workflow_result(
                  Spree.fulfillment_update_workflow.call(
                    fulfillment: @fulfillment, fulfillment_attributes: update_attributes
                  )
                )
              end
            end

            # PATCH /api/v3/seller/orders/:order_id/fulfillments/:id/cancel
            #
            # A parcel this seller is not going to send after all. Restocking
            # and standing the carrier down happen inside the workflow.
            def cancel
              run_workflow(Spree.fulfillment_cancel_workflow)
            end

            # PATCH /api/v3/seller/orders/:order_id/fulfillments/:id/split
            #
            # Moves part of what this parcel holds onto one of its own, for
            # goods leaving separately. The variant is resolved through the
            # order rather than the catalogue: what may be split is what this
            # parcel is actually carrying.
            def split
              with_order_lock do
                variant = @order.variants.find_by_prefix_id!(params[:variant_id])

                changer = @fulfillment.transfer_to_location(
                  variant, params[:quantity].to_i, split_stock_location
                )

                if changer.run!
                  render json: {
                    data: @order.reload.fulfillments.map { |fulfillment| serialize(fulfillment) }
                  }
                else
                  render_validation_error(changer.errors)
                end
              end
            end

            protected

            def read_actions
              %w[index show]
            end

            private

            def set_order
              @order = current_seller_orders.find_by_prefix_id!(params[:order_id])
              authorize! :show, @order
            end

            WRITE_ACTIONS = %w[update fulfill cancel split].freeze

            def set_fulfillment
              @fulfillment = @order.fulfillments.find_by_prefix_id!(params[:id])
              authorize! :update, @fulfillment if WRITE_ACTIONS.include?(action_name)
            end

            def fulfill_params
              @fulfill_params ||= params.permit(
                :tracking, :tracking_carrier, :notify_customer, items: [:item_id, :quantity]
              )
            end

            def update_params
              params.permit(:tracking, :tracking_carrier, :stock_location_id,
                            :selected_delivery_rate_id)
            end

            # The payload the workflow gets. The workflow takes a raw
            # `stock_location_id`, so the prefixed id is resolved through the
            # seller's own shelves first — a marketplace warehouse 404s here
            # rather than reaching the assignment.
            def update_attributes
              attributes = update_params.to_h

              if update_params[:stock_location_id].present?
                location = current_seller.stock_locations.
                           find_by_prefix_id!(update_params[:stock_location_id])
                attributes['stock_location_id'] = location.id
              end

              attributes
            end

            # Where the split half ships from. The seller's own shelves only —
            # defaulting to where this parcel already sits.
            def split_stock_location
              return @fulfillment.stock_location if params[:stock_location_id].blank?

              current_seller.stock_locations.find_by_prefix_id!(params[:stock_location_id])
            end

            def run_workflow(workflow)
              with_order_lock do
                render_workflow_result(workflow.call(fulfillment: @fulfillment))
              end
            end

            def render_workflow_result(result)
              if result.success?
                render json: serialize(result.value)
              else
                render_result_error(result)
              end
            end

            # The workflow addresses what to ship by line item, and the lookup
            # runs through the order so an id from elsewhere cannot be shipped.
            def items_for_fulfill
              return if fulfill_params[:items].nil?

              fulfill_params[:items].map do |item|
                {
                  line_item: @order.line_items.find_by_prefix_id!(item[:item_id]),
                  quantity: Integer(item[:quantity].to_s, exception: false)
                }
              end
            end

            # Only an explicit false suppresses the email; an omitted flag
            # keeps sending it, as the operator's endpoint does.
            def notify_customer?(value)
              !ActiveModel::Type::Boolean.new.cast(value).equal?(false)
            end

            def serialize(fulfillment)
              Spree.api.seller_fulfillment_serializer.new(
                fulfillment, params: { store: current_store }
              ).to_h
            end
          end
        end
      end
    end
  end
end
