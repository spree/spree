module Spree
  module Admin
    class StockMovementsController < Spree::Admin::BaseController
      respond_to :html

      def index
        @stock_movements = @stock_location.stock_movements
      end

      private

      def stock_location
        @stock_location ||= StockLocation.find(params[:stock_location_id])
      end
    end
  end
end
