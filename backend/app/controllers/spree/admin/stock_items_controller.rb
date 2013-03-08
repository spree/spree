module Spree
  module Admin
    class StockItemsController < Spree::Admin::BaseController
      before_filter :determine_backorderable

      def update
        stock_item.save
        respond_to do |format|
          format.js { head :ok }
        end
      end

      private

      def stock_item
        @stock_item ||= StockItem.find(params[:id])
      end

      def determine_backorderable
        stock_item.backorderable = params[:stock_item].present? && params[:stock_item][:backorderable].present? ? true : false
      end
    end
  end
end
