module Spree
  module Admin
    class StockLocationsController < ResourceController
      before_filter :load_data

      def transfer_stock
        @variant = Variant.find(params[:variant_id])

        if !valid_stock_transfer?
          flash[:error] = t(:not_enough_stock)
          redirect_to :back and return
        end

        variants = { @variant => params[:quantity].to_i }
        stock_transfer = StockTransfer.create(:reference_number => params[:reference_number])
        stock_transfer.transfer(source_location,
                                destination_location,
                                variants)
        flash[:success] = t(:stock_successfully_transferred)

        redirect_to :back
      end

      private

      def load_data
        @variants = Variant.all
      end

      def valid_stock_transfer?
        source_location != destination_location &&
        source_location.stock_item(@variant).count_on_hand > params[:quantity].to_i
      end


      def source_location
        @source_location ||= StockLocation.find(params[:stock_location_from_id])
      end

      def destination_location
        @destination_location ||= StockLocation.find(params[:stock_location_to_id])
      end
    end
  end
end
