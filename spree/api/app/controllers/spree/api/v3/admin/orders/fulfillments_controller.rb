module Spree
  module Api
    module V3
      module Admin
        module Orders
          # The parcels owed on an order.
          #
          # Shipping, cancelling and splitting live in the shared concern;
          # what is here is what makes them the operator's — the store-wide
          # scope every id in a payload resolves through, and the two actions
          # only an operator has.
          class FulfillmentsController < BaseController
            include Spree::Api::V3::Orders::FulfillmentActions

            scoped_resource :fulfillments

            request_params :fulfillment do |body|
              body.external_references
              body.attribute :stock_location_id, :id,
                required: true, on: :create,
                description: "The location the fulfillment ships from. On update, moving it re-prices the fulfillment against that location's rates."
              body.attribute :source_fulfillment_id, :id,
                only: :create,
                description: "The only fulfillment of this order to move units from, its exchange and claim replacements included: how a canceled replacement is sent again. Omitted, the customer's bought units are taken from every unshipped fulfillment."
              body.attribute :tracking, :string,
                description: 'Carrier tracking number, or a full `https://` tracking link, which is served back as `tracking_url` unchanged.'
              body.attribute :tracking_carrier, :string,
                only: :update,
                description: "Which carrier the tracking number belongs to: a slug from the tracking carriers endpoint. Left blank, it is detected from the number's format where possible."
              body.attribute :selected_delivery_rate_id, :id, only: :update
              body.attribute :delivery_method_id, :id,
                only: :create,
                description: 'Delivery method attached as the selected rate. Defaults to the delivery method of the fully drained source fulfillments.'
              body.attribute :cost, :decimal,
                only: :create,
                example: '7.42',
                description: 'Explicit shipping cost, such as the 3PL price. Defaults to the summed cost of the fully drained source fulfillments, which keeps the order total unchanged. Persists only with `status: shipped`; pending fulfillments are re-priced by the rate engine.'
              body.attribute :status, :string,
                only: :create,
                choices: %w[shipped],
                description: 'Pass `shipped` to register an already-shipped external fulfillment.'
              body.attribute :metadata, :hash, only: :create
              body.attribute :items, :array,
                only: :create,
                description: 'Line item quantities to fulfill. Omit to fulfill every unit not yet shipped.' do |item|
                item.attribute :item_id, :id, required: true
                item.attribute :quantity, :integer, required: true
              end
            end

            request_params 'FulfillmentFulfillParams', action: :fulfill do |body|
              body.attribute :items, :array,
                description: 'Line item quantities to ship. Omit to ship everything the fulfillment holds; a subset is split onto a new fulfillment, which is the one that ships.' do |item|
                item.attribute :item_id, :id, required: true
                item.attribute :quantity, :integer, required: true
              end
              body.attribute :tracking, :string,
                description: 'Carrier tracking number or a full `https://` tracking link, stored on the fulfillment that ships.'
              body.attribute :tracking_carrier, :string,
                description: 'Which carrier the number belongs to; detected from the number when omitted.'
              body.attribute :notify_customer, :boolean,
                description: 'Whether the customer gets the shipment email. Defaults to true; pass false to suppress it for this dispatch only.'
              body.attribute :force, :boolean,
                description: 'Hand the goods over even though the order is unpaid or holds backordered units.'
            end

            request_params 'FulfillmentMarkDeliveredParams', action: :mark_delivered do |body|
              body.attribute :delivered_at, :datetime,
                description: 'When it arrived. Defaults to now; return windows run from this time.'
              body.attribute :notify_customer, :boolean,
                description: 'Whether the customer gets a delivery notification. Defaults to true.'
            end

            request_params 'FulfillmentSplitParams', action: :split do |body|
              body.attribute :variant_id, :id, required: true, description: 'The variant being moved out.'
              body.attribute :quantity, :integer, required: true
              body.attribute :stock_location_id, :id,
                description: "Origin of the new fulfillment. Defaults to the source fulfillment's location."
            end

            before_action :set_resource, only: [:show, :update, :fulfill, :mark_delivered, :cancel, :split]

            # POST /api/v3/admin/orders/:order_id/fulfillments
            #
            # Manually registers a fulfillment on a completed order (external
            # carrier / 3PL sync), bypassing order routing. Moves the requested
            # line item quantities out of their routed fulfillments; when
            # `items` is omitted, everything not yet shipped is moved. Exchange
            # and claim replacements are moved only out of a named
            # `source_fulfillment_id`, which is how a canceled replacement is
            # sent again. An explicit `cost` persists only with
            # `status: 'shipped'` — pending fulfillments are re-priced by the
            # rate engine.
            def create
              authorize!(:create, Spree::Fulfillment)

              with_order_lock do
                result = Spree.fulfillment_create_workflow.call(
                  order: @order,
                  stock_location: stock_location_for_create,
                  items: items_for_create,
                  source_fulfillment: source_fulfillment_for_create,
                  tracking: create_params[:tracking],
                  delivery_method: delivery_method_for_create,
                  cost: create_params[:cost],
                  status: create_params[:status],
                  metadata: create_params[:metadata]&.to_h
                )

                render_result(result, status: :created)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fulfillments/:id/mark_delivered
            #
            # Staff confirming the parcel arrived. Deliberately the operator's
            # alone: that goods arrived is the buyer's word, not the sender's.
            def mark_delivered
              with_order_lock do
                result = Spree.fulfillment_mark_delivered_workflow.call(
                  fulfillment: @resource,
                  delivered_at: mark_delivered_params[:delivered_at],
                  notify_customer: notify_customer?(mark_delivered_params[:notify_customer])
                )

                render_result(result)
              end
            end

            protected

            def serializer_class
              Spree.api.admin_fulfillment_serializer
            end

            def collection_includes
              [:deliveries, { shipping_labels: { file_attachment: :blob } }]
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end

            # A replayed create runs the update action, which takes neither the
            # units to move nor how the parcel was registered: those only shape
            # a new fulfillment.
            def normalize_upsert_params!
              %i[items source_fulfillment_id delivery_method_id cost status metadata].each { |key| params.delete(key) }
            end

            private

            # Forcing past a stock or payment guard is the operator's call.
            def fulfill_workflow_options
              { force: fulfill_params[:force].to_b }
            end

            # The whole catalogue, and any warehouse this staff member may
            # see: an operator ships anything the store sells.
            def variant_for_split
              current_store.variants.find_by_prefix_id!(params[:variant_id])
            end

            def stock_location_for_split
              return @resource.stock_location if params[:stock_location_id].blank?

              find_stock_location!(params[:stock_location_id])
            end

            def create_params
              @create_params ||= params.permit(*declared_permitted_attributes)
            end

            def mark_delivered_params
              @mark_delivered_params ||= params.permit(*declared_permitted_attributes)
            end

            def find_stock_location!(id)
              current_store.stock_locations.accessible_by(current_ability, :show).find_by_prefix_id!(id)
            end

            def stock_location_for_create
              find_stock_location!(create_params.require(:stock_location_id))
            end

            def delivery_method_for_create
              return if create_params[:delivery_method_id].blank?

              Spree::DeliveryMethod.accessible_by(current_ability, :show).find_by_prefix_id!(create_params[:delivery_method_id])
            end

            def source_fulfillment_for_create
              return if create_params[:source_fulfillment_id].blank?

              @order.fulfillments.find_by_prefix_id!(create_params[:source_fulfillment_id])
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
