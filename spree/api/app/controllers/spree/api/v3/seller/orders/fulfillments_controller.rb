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
            before_action :set_fulfillment, only: [:show, :fulfill]

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

            protected

            def read_actions
              %w[index show]
            end

            private

            def set_order
              @order = current_seller_orders.find_by_prefix_id!(params[:order_id])
              authorize! :show, @order
            end

            def set_fulfillment
              @fulfillment = @order.fulfillments.find_by_prefix_id!(params[:id])
              authorize! :update, @fulfillment if action_name == 'fulfill'
            end

            def fulfill_params
              @fulfill_params ||= params.permit(
                :tracking, :tracking_carrier, :notify_customer, items: [:item_id, :quantity]
              )
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
