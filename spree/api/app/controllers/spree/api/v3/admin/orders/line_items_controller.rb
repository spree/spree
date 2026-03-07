module Spree
  module Api
    module V3
      module Admin
        module Orders
          class LineItemsController < BaseController
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

            def permitted_params
              params.permit(*Spree::PermittedAttributes.line_item_attributes, { options: {} })
            end

            private

            def variant
              @variant ||= current_store.variants.find_by_prefix_id!(permitted_params[:variant_id])
            end
          end
        end
      end
    end
  end
end
