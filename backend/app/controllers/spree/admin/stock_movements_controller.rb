module Spree
  module Admin
    class StockMovementsController < Spree::Admin::BaseController
      respond_to :html
      helper_method :stock_location

      def index
        @stock_movements = stock_location.stock_movements.recent.
          includes(:stock_item => { :variant => :product }).
          page(params[:page])
      end

      def new
        @stock_movement = stock_location.stock_movements.build
      end

      def create
        @stock_movement = stock_location.stock_movements.build(stock_movement_params)
        @stock_movement.save
        flash[:success] = flash_message_for(@stock_movement, :successfully_created)
        redirect_to admin_stock_location_stock_movements_path(stock_location)
      end

      def edit
        @stock_movement = StockMovement.find(params[:id])
      end

      private

      def stock_location
        @stock_location ||= StockLocation.find(params[:stock_location_id])
      end

      def stock_movement_params
        params.require(:stock_movement).permit(:quantity, :stock_item_id, :action)
      end
    end
  end
end
