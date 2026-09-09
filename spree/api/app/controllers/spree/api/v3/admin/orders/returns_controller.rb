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

            before_action :set_resource, only: [:show, :update, :approve, :receive, :refund, :cancel]

            # PATCH /api/v3/admin/orders/:order_id/returns/:id
            #
            # Editable fields only — status moves through the member actions.
            def update
              if @resource.update(permitted_params)
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
              params.permit(:memo, :reason_id, :stock_location_id, metadata: {})
            end

            private

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
