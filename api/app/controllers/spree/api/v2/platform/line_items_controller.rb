module Spree
  module Api
    module V2
      module Platform
        class LineItemsController < ResourceController
          before_action :find_order, only: [:new, :create, :update, :destroy]
          before_action :find_line_item, only: [:update, :destroy]

          def create
            variant = Spree::Variant.find(params[:line_item][:variant_id])
            result = add_item_service.call(order: @order,
                                           variant: variant,
                                           quantity: params[:line_item][:quantity],
                                           options: params[:options])

            render_line_item(result)
          end

          def update
            return render_error_item_quantity unless params[:quantity].to_i > 0

            result = adjust_quantity_service.call(order: @order,
                                                  line_item: @line_item,
                                                  quantity: params[:quantity])

            render_line_item(result)
          end

          def destroy
            spree_authorize! :update, @order

            remove_line_item_service.call(
              order: @order,
              line_item: @line_item
            )

            render_serialized_payload { @line_item }
          end

          private

          def model_class
            Spree::LineItem
          end

          def add_item_service
            Spree::Api::Dependencies.platform_line_item_add_service.constantize
          end

          def remove_line_item_service
            Spree::Api::Dependencies.platform_line_item_remove_service.constantize
          end

          def adjust_quantity_service
            Spree::Api::Dependencies.platform_line_item_set_quantity_service.constantize
          end

          def render_line_item(result)
            if result.success?
              render_serialized_payload { serialize_resource(result.value) }
            else
              render_error_payload(result.error)
            end
          end

          def find_order
            @order ||= current_store.orders.includes(:line_items).find_by!(number: params[:order_id])
            spree_authorize! :update, @order
          end

          def find_line_item
            id = params[:id].to_i
            @line_item = @order.line_items.detect { |line_item| line_item.id == id } or
              raise ActiveRecord::RecordNotFound

            spree_authorize! :update, @line_item
          end
        end
      end
    end
  end
end
