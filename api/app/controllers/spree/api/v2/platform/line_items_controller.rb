module Spree
  module Api
    module V2
      module Platform
        class LineItemsController < ResourceController
          class_attribute :line_item_options

          self.line_item_options = []

          def new; end

          def create
            variant = Spree::Variant.find(params[:line_item][:variant_id])

            result = Spree::Dependencies.cart_add_item_service.constantize.call(order: order,
                                                                                    variant: variant,
                                                                                    quantity: params[:line_item][:quantity],
                                                                                    options: line_item_params[:options]).value
            render_serialized_payload(201) { serialize_resource(result) }
          end

          def update
            @line_item = find_line_item

            if Spree::Dependencies.cart_update_service.constantize.call(order: @order, params: line_items_attributes).success?
              @line_item.reload
              render_serialized_payload(200) { serialize_resource(@line_item) }
            else
              invalid_resource!(@line_item)
            end
          end

          def destroy
            spree_authorize! :update, @order
            @line_item = find_line_item
            Spree::Dependencies.cart_remove_line_item_service.constantize.call(order: @order, line_item: @line_item)

            render_serialized_payload(204) { serialize_resource(@line_item) }
          end

          private

          def model_class
            Spree::LineItem
          end

          def order
            @order ||= Spree::Order.includes(:line_items).find_by!(number: params[:order_id])
            authorize! :update, @order
          end

          def find_line_item
            id = params[:id].to_i
            order.line_items.detect { |line_item| line_item.id == id } or
              raise ActiveRecord::RecordNotFound
          end

          def line_items_attributes
            { line_items_attributes: {
              id: params[:id],
              quantity: params[:line_item][:quantity],
              options: line_item_params[:options] || {}
            } }
          end

          def line_item_params
            params.require(:line_item).permit(:quantity, :variant_id, options: line_item_options)
          end

          def render_line_item(result)
            if result.success?
              render_serialized_payload { @line_item }
            else
              render_error_payload(result.error)
            end
          end
        end
      end
    end
  end
end
