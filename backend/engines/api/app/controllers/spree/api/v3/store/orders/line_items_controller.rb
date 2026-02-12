module Spree
  module Api
    module V3
      module Store
        module Orders
          class LineItemsController < ResourceController
            include Spree::Api::V3::OrderConcern

            skip_before_action :set_resource
            before_action :authorize_order_access!

            # POST  /api/v3/store/orders/:order_id/line_items
            def create
              result = Spree.cart_add_item_service.call(
                order: @parent,
                variant: variant,
                quantity: permitted_params[:quantity] || 1,
                options: permitted_params[:options] || {}
              )

              if result.success?
                @line_item = result.value
                render json: serialize_resource(@line_item), status: :created
              else
                render_service_error(result.error, code: ERROR_CODES[:insufficient_stock])
              end
            end

            # PATCH  /api/v3/store/orders/:order_id/line_items/:id
            def update
              @line_item = scope.find_by_prefix_id!(params[:id])

              if permitted_params[:quantity].present?
                result = Spree.cart_set_item_quantity_service.call(
                  order: @parent,
                  line_item: @line_item,
                  quantity: permitted_params[:quantity]
                )

                if result.success?
                  render json: serialize_resource(@line_item)
                else
                  render_service_error(result.error, code: ERROR_CODES[:invalid_quantity])
                end
              else
                render json: serialize_resource(@line_item)
              end
            end

            # DELETE  /api/v3/store/orders/:order_id/line_items/:id
            def destroy
              @line_item = scope.find_by_prefix_id!(params[:id])

              Spree.cart_remove_line_item_service.call(
                order: @parent,
                line_item: @line_item
              )

              head :no_content
            end

            protected

            def parent_association
              :line_items
            end

            def variant
              @variant ||= current_store.variants.accessible_by(current_ability).find_by_prefix_id!(permitted_params[:variant_id])
            end

            def model_class
              Spree::LineItem
            end

            def serializer_class
              Spree.api.line_item_serializer
            end

            def permitted_params
              params.permit(Spree::PermittedAttributes.line_item_attributes + [{ options: {} }])
            end
          end
        end
      end
    end
  end
end
