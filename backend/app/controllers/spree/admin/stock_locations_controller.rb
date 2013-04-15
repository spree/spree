module Spree
  module Admin
    class StockLocationsController < ResourceController
      before_filter :load_data

      def transfer_stock
        prepare_stock_transfer

        movement_from = StockMovement.new(stock_item: @stock_item_from, originator: from_location, quantity: -params[:quantity].to_i)
        movement_to = StockMovement.new(stock_item: @stock_item_to, originator: to_location, quantity: params[:quantity].to_i)

        if movement_from.save && movement_to.save
          flash[:success] = t(:stock_successfully_transferred)
        else
          flash[:error] = t(:stock_not_transferred)
        end
        redirect_to :back
      end

      private

      def load_data
        @variants = Variant.all
      end

      def prepare_stock_transfer
        variant = Variant.find(params[:variant_id])
        @stock_item_from = from_location.stock_item(variant)
        @stock_item_to = to_location.stock_item(variant)
      end

      def from_location
        @from ||= StockLocation.find(params[:stock_location_from_id])
      end

      def to_location
        @to ||= StockLocation.find(params[:stock_location_to_id])
      end
    end
  end
end
