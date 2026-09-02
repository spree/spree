module Spree
  module Api
    module V3
      module Admin
        module Orders
          class ItemsController < BaseController
            # POST /api/v3/admin/orders/:order_id/items
            def create
              with_order_lock do
                result = Spree.order_add_item_service.call(
                  order: @parent,
                  variant: variant,
                  quantity: permitted_params[:quantity] || 1,
                  options: permitted_params[:options] || {},
                  **manual_price_arguments
                )

                if result.success?
                  render json: serialize_resource(result.value), status: :created
                else
                  render_order_item_error(result, default_code: ERROR_CODES[:insufficient_stock])
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/items/:id
            def update
              with_order_lock do
                result = Spree.order_update_item_service.call(
                  order: @parent,
                  line_item: @resource,
                  quantity: permitted_params[:quantity],
                  metadata: permitted_params[:metadata]&.to_h,
                  **manual_price_arguments
                )

                if result.success?
                  render json: serialize_resource(@resource.reload)
                else
                  render_order_item_error(result, default_code: ERROR_CODES[:invalid_quantity])
                end
              end
            end

            # DELETE /api/v3/admin/orders/:order_id/items/:id
            def destroy
              with_order_lock do
                Spree.order_remove_line_item_service.call(
                  order: @parent,
                  line_item: @resource
                )

                head :no_content
              end
            end

            protected

            def model_class
              Spree::LineItem
            end

            def serializer_class
              Spree.api.admin_line_item_serializer
            end

            def parent_association
              :line_items
            end

            def permitted_params
              params.permit(:variant_id, :quantity, :price, metadata: {}, options: {})
            end

            private

            # price is tri-state — absent leaves pricing alone, an amount
            # negotiates the line, an explicit null reverts to catalog
            # pricing — so it is forwarded only when the request carried the
            # key, which also keeps custom services without the keyword
            # working for every other request.
            def manual_price_arguments
              return {} unless params.key?(:price)

              { price: permitted_params[:price] }
            end

            def variant
              @variant ||= current_store.variants.find_by_prefix_id!(permitted_params[:variant_id])
            end

            # Renders a failed add/update with a code inferred from symbolic errors.
            #
            # @param result [Spree::ServiceModule::Result] failed service outcome
            # @param default_code [String] fallback when the error carries no symbol
            def render_order_item_error(result, default_code:)
              error = result.error
              errors = error.respond_to?(:value) ? error.value : error
              code = infer_line_item_error_code(errors, default: default_code)

              render_service_error(error, code: code)
            end
          end
        end
      end
    end
  end
end
