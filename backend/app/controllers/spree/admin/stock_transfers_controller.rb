module Spree
  module Admin
    class StockTransfersController < ResourceController
      before_filter :load_stock_locations, :only => :index

      def collection
        @q = StockTransfer.search(params[:q])

        @q.result
          .includes(:stock_movements => { :stock_item => :stock_location })
          .order('created_at DESC')
          .page(params[:page])
      end

      private
      def load_stock_locations
        @stock_locations = Spree::StockLocation.active.order('name ASC')
      end
    end
  end
end
