module Spree
  module Api
    class LineItemsController < Spree::Api::BaseController

      def create
        variant = Spree::Variant.find(params[:line_item][:variant_id])
        @line_item = order.contents.add(variant, params[:line_item][:quantity])
        if @line_item.save
          respond_with(@line_item, :status => 201, :default_template => :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def update
        @line_item = order.line_items.find(params[:id])
        if @line_item.update_attributes(params[:line_item], :as => :api)
          respond_with(@line_item, :default_template => :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def destroy
        @line_item = order.line_items.find(params[:id])
        @line_item.destroy
        respond_with(@line_item, :status => 204)
      end

      private

      def order
        @order ||= Order.find_by_number!(params[:order_id])
        authorize! :update, @order, params[:order_token]
      end
    end
  end
end
