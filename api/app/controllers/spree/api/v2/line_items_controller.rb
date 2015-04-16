module Spree
  module Api
    module V2
      class LineItemsController < Spree::Api::BaseController
        class_attribute :line_item_options

        self.line_item_options = []

        def create
          variant = Spree::Variant.find(params[:line_item][:variant_id])
          @line_item = order.contents.add(
              variant,
              params[:line_item][:quantity] || 1,
              line_item_params[:options] || {}
          )

          if @line_item.errors.empty?
            render json: @line_item, status: 201
          else
            invalid_resource!(@line_item)
          end
        end

        def update
          @line_item = find_line_item
          if @order.contents.update_cart(line_items_attributes)
            @line_item.reload
            render json: @line_item
          else
            invalid_resource!(@line_item)
          end
        end

        def destroy
          @line_item = find_line_item
          variant = Spree::Variant.unscoped.find(@line_item.variant_id)
          @order.contents.remove(variant, @line_item.quantity)
          render json: @line_item, status: 204
        end

        private
          def order
            @order ||= Spree::Order.includes(:line_items).find_by!(number: order_id)
            authorize! :update, @order, order_token
          end

          def find_line_item
            id = params[:id].to_i
            order.line_items.detect { |line_item| line_item.id == id } or
                raise ActiveRecord::RecordNotFound
          end

          def line_items_attributes
            {line_items_attributes: {
                id: params[:id],
                quantity: params[:line_item][:quantity],
                options: line_item_params[:options] || {}
            }}
          end

          def line_item_params
            params.require(:line_item).permit(
                :quantity,
                :variant_id,
                options: line_item_options
            )
          end
      end
    end
  end
end
