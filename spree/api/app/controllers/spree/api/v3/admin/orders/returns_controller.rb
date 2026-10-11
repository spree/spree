module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Returns on a completed order. Every status change goes through its
          # own member action rather than mass assignment, because each one is
          # a workflow with its own arguments — receiving carries the
          # quantities the warehouse counted, refunding carries a method and
          # an amount.
          class ReturnsController < BaseController
            include Spree::Api::V3::Orders::ReturnActions

            # Returns are a subject of the `orders` catalog resource (see
            # Spree::PermissionConfiguration), so `read_orders`/`write_orders`
            # gate these endpoints — matching the cross-order ReturnsController.
            # Declaring `:returns` here would name a key no catalog knows: the
            # JWT gate would silently no-op and a `write_orders` secret key
            # would be wrongly denied.
            scoped_resource :orders

            request_params :return do |body|
              body.attribute :items, :array,
                required: true, on: :create,
                only: :create,
                description: 'Fulfilled units coming back, and how many of each.' do |item|
                item.attribute :fulfillment_item_id, :id, required: true
                item.attribute :quantity, :integer, required: true
              end
              body.attribute :stock_location_id, :id,
                description: 'Where the goods come back to. Defaults to the location that shipped them.'
              body.attribute :reason_id, :id, description: "One of the store's return reasons."
              body.attribute :memo, :string
              body.attribute :metadata, :hash, only: :update
            end

            request_params 'ReturnReceiveParams', action: :receive do |body|
              body.attribute :items, :array,
                description: 'What actually arrived. Omit to receive everything as requested and resellable; send rows for a partial or damaged receipt.' do |item|
                item.attribute :return_line_item_id, :id, required: true
                item.attribute :quantity, :integer, required: true
                item.attribute :resellable, :boolean,
                  description: 'Goods that cannot be resold are received but never restocked. Defaults to true.'
              end
            end

            request_params 'ReturnRefundParams', action: :refund do |body|
              body.attribute :amount, :decimal, description: 'Defaults to the value of what was actually received.'
              body.attribute :refund_method, :string,
                choices: Spree::RefundMethods::METHODS,
                description: '`store_credit` issues credit immediately; `original_payment` (the default) refunds through the gateway that took the money.'
            end

            request_params 'ReturnCancelParams', action: :cancel do |body|
              body.attribute :reason, :string, description: 'A note on why the return was canceled.'
            end

            before_action :set_resource, only: [:show, :update, :approve, :receive, :refund, :cancel]

            # PATCH /api/v3/admin/orders/:order_id/returns/:id
            #
            # Editable fields only — status moves through the member actions.
            def update
              if @resource.update(update_attributes)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            protected

            def serializer_class
              Spree.api.admin_return_serializer
            end

            # `documents` resolves the provider through the returned units and
            # reads the labels it produced, so both are preloaded: without them
            # a page of returns is a query per row.
            def collection_includes
              [
                :reason, :stock_location, :deliveries,
                { shipping_labels: { file_attachment: :blob } },
                { return_line_items: [:variant, :line_item, { fulfillment_item: :fulfillment }] }
              ]
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end

            private

            # The ids are resolved through the store rather than assigned raw,
            # so another store's reason or warehouse reads as missing.
            def update_attributes
              attributes = permitted_params.to_h.except('reason_id', 'stock_location_id')

              if params.key?(:reason_id)
                attributes['reason'] =
                  (current_store.return_reasons.find_by_prefix_id!(params[:reason_id]) if params[:reason_id].present?)
              end

              if params.key?(:stock_location_id)
                attributes['stock_location'] =
                  if params[:stock_location_id].present?
                    current_store.stock_locations.accessible_by(current_ability, :show).
                      find_by_prefix_id!(params[:stock_location_id])
                  end
              end

              attributes
            end

            # Any of the store's warehouses the caller may see.
            def stock_location_for_create
              return nil if create_params[:stock_location_id].blank?

              current_store.stock_locations.accessible_by(current_ability, :show).
                find_by_prefix_id!(create_params[:stock_location_id])
            end
          end
        end
      end
    end
  end
end
