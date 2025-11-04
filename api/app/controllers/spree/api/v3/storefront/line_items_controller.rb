module Spree
  module Api
    module V3
      module Storefront
        class LineItemsController < ResourceController
          include Spree::Api::V3::GuestOrderAccess

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
            @line_item = @order.contents.add(
              variant,
              line_item_params[:quantity] || 1,
              line_item_params[:options] || {}
            )

            if @line_item.persisted?
              render json: serialize_resource(@line_item), status: :created
            else
              render_errors(@line_item.errors)
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
              @order.contents.update_cart_line_item(
                @line_item,
                quantity: line_item_params[:quantity]
              )
            end

            render json: serialize_resource(@line_item)
          end

          # DELETE /api/v3/storefront/orders/:order_id/line_items/:id
          def destroy
            @line_item = @order.line_items.find(params[:id])
            @order.contents.remove_line_item(@line_item)
            head :no_content
          end

          protected

          def set_order
            @order = Spree::Order.find_by!(number: params[:order_id])
          end

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
            params.require(:line_item).permit(:variant_id, :quantity, options: {})
          end
        end
      end
    end
  end
end
