module Spree
  module Admin
    class StockItemsController < Spree::Admin::BaseController
      def update
        respond_to do |format|
          format.js { head :ok }
        end
      end

      private

      def stock_item
        @stock_item ||= StockItem.find(params[:id])
      end

      def determine_backorderable
        @stock_item.backorderable = params[:stock_item_backorderable].present? ? true : false
      end
    end
  end
end
