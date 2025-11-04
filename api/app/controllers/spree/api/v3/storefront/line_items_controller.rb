module Spree
  module Api
    module V3
      module Storefront
        class LineItemsController < ResourceController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!
          skip_before_action :set_resource

          # GET /api/v3/storefront/orders/:order_id/line_items
          def index
            render json: {
              data: serialize_collection(@order.line_items)
            }
          end

          # POST /api/v3/storefront/orders/:order_id/line_items
          def create
            result = add_item_service.call(
              order: @order,
              variant: variant,
              quantity: line_item_params[:quantity] || 1,
              options: line_item_params[:options] || {}
            )

            if result.success?
              @line_item = result.value
              render json: serialize_resource(@line_item), status: :created
            else
              render_service_error(result.error, code: ERROR_CODES[:insufficient_stock])
            end
          end

          # GET /api/v3/storefront/orders/:order_id/line_items/:id
          def show
            @line_item = @order.line_items.find(params[:id])
            render json: serialize_resource(@line_item)
          end

          # PATCH /api/v3/storefront/orders/:order_id/line_items/:id
          def update
            @line_item = @order.line_items.find(params[:id])

            if line_item_params[:quantity].present?
              result = set_item_quantity_service.call(
                order: @order,
                line_item: @line_item,
                quantity: line_item_params[:quantity]
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

          # DELETE /api/v3/storefront/orders/:order_id/line_items/:id
          def destroy
            @line_item = @order.line_items.find(params[:id])

            remove_line_item_service.call(
              order: @order,
              line_item: @line_item
            )

            head :no_content
          end

          protected

          def variant
            Spree::Variant.find(line_item_params[:variant_id])
          end

          def model_class
            Spree::LineItem
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_line_item_serializer.constantize
          end

          def permitted_params
            line_item_params
          end

          def line_item_params
            params.require(:line_item).permit(Spree::PermittedAttributes.line_item_attributes + [{ options: {} }])
          end

          def add_item_service
            Spree::Api::Dependencies.storefront_cart_add_item_service.constantize
          end

          def set_item_quantity_service
            Spree::Api::Dependencies.storefront_cart_set_item_quantity_service.constantize
          end

          def remove_line_item_service
            Spree::Api::Dependencies.storefront_cart_remove_line_item_service.constantize
          end
        end
      end
    end
  end
end
