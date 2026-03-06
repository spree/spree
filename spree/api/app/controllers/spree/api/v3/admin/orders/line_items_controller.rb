module Spree
  module Api
    module V3
      module Admin
        module Orders
          class LineItemsController < ResourceController
            include Spree::Api::V3::OrderLock

            before_action :authorize_order_access!
            skip_before_action :set_resource, only: [:index, :create]
            before_action :set_line_item, only: [:show, :update, :destroy]

            # POST /api/v3/admin/orders/:order_id/line_items
            def create
              with_order_lock do
                result = Spree.cart_add_item_service.call(
                  order: @parent,
                  variant: variant,
                  quantity: permitted_params[:quantity] || 1,
                  options: permitted_params[:options] || {}
                )

                if result.success?
                  render json: serialize_resource(result.value), status: :created
                else
                  render_service_error(result.error, code: ERROR_CODES[:insufficient_stock])
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/line_items/:id
            def update
              with_order_lock do
                if permitted_params[:quantity].present?
                  result = Spree.cart_set_item_quantity_service.call(
                    order: @parent,
                    line_item: @resource,
                    quantity: permitted_params[:quantity]
                  )

                  if result.success?
                    render json: serialize_resource(@resource.reload)
                  else
                    render_service_error(result.error, code: ERROR_CODES[:invalid_quantity])
                  end
                else
                  if @resource.update(permitted_params.except(:variant_id, :quantity))
                    render json: serialize_resource(@resource)
                  else
                    render_errors(@resource.errors)
                  end
                end
              end
            end

            # DELETE /api/v3/admin/orders/:order_id/line_items/:id
            def destroy
              with_order_lock do
                Spree.cart_remove_line_item_service.call(
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

            def set_parent
              @parent = current_store.orders.find_by_prefix_id!(params[:order_id])
              @order = @parent # needed for OrderLock
            end

            def authorize_order_access!
              authorize!(:show, @parent)
            end

            def set_line_item
              @resource = @parent.line_items.find_by_prefix_id!(params[:id])
              authorize_resource!(@resource)
            end

            def variant
              @variant ||= current_store.variants.find_by_prefix_id!(permitted_params[:variant_id])
            end

            def permitted_params
              params.permit(:variant_id, :quantity, { metadata: {}, options: {} })
            end
          end
        end
      end
    end
  end
end
