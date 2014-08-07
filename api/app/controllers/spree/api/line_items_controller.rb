module Spree
  module Api
    class LineItemsController < Spree::Api::BaseController
      before_action :load_order, except: [:new]

      def create
        @line_item = create_line_item(@order,
                                      params[:line_item][:variant_id],
                                      params[:line_item][:quantity])

        if @line_item.errors.empty?
          respond_with(@line_item, status: 201, default_template: :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def update
        @line_item = find_line_item(@order)
        if @order.contents.update_cart(line_items_attributes)
          @line_item.reload
          respond_with(@line_item, default_template: :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def destroy
        @line_item = find_line_item(@order)
        variant = Spree::Variant.find(@line_item.variant_id)
        @order.contents.remove(variant, @line_item.quantity)
        respond_with(@line_item, status: 204)
      end

      private
        def load_order
          @order ||= Spree::Order.includes(:line_items).find_by!(number: order_id)
          authorize! :update, @order, order_token
        end

        def create_line_item(order, variant_id, quantity)
          variant = Spree::Variant.find(variant_id)
          order.contents.add(variant, quantity || 1)
        end

        def line_item_exists_for_order(order, variant_id)
          Spree::LineItem.where(order: order).where(variant_id: variant_id).first
        end

        def find_line_item(order)
          id = params[:id].to_i
          order.line_items.detect {|line_item| line_item.id == id} or
            raise ActiveRecord::RecordNotFound
        end

        def line_items_attributes
          { line_items_attributes: {
            id: params[:id],
            quantity: params[:line_item][:quantity]
          } }
        end

        def line_item_params
          params.require(:line_item).permit(:quantity, :variant_id)
        end
    end
  end
end
