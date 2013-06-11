module Spree
  module Api
    class LineItemsController < Spree::Api::BaseController

      def create
        authorize! :update, order
        @line_item = order.line_items.build(line_item_params)
        if @line_item.save
          respond_with(@line_item, :status => 201, :default_template => :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def update
        authorize! :update, order
        @line_item = order.line_items.find(params[:id])
        if @line_item.update_attributes(line_item_params)
          respond_with(@line_item, :default_template => :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def destroy
        authorize! :update, order
        @line_item = order.line_items.find(params[:id])
        @line_item.destroy
        respond_with(@line_item, :status => 204)
      end

      private

      def order
        @order ||= Order.find_by_number!(params[:order_id])
        authorize! :read, @order
      end

      def line_item_params
        params.require(:line_item).permit(:quantity, :variant_id)
      end
    end
  end
end
