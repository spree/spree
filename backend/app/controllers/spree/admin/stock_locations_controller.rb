module Spree
  module Admin
    class StockLocationsController < ResourceController

      def transfer_stock
        @variant = Variant.find(params[:bulk_variant])

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
      def valid_stock_transfer?
        source_location != destination_location &&
        source_location.stock_item(@variant).count_on_hand > params[:quantity].to_i
      end

      def source_location
        @source_location ||= StockLocation.find(params[:bulk_source_location_id])
      end

      def destination_location
        @destination_location ||= StockLocation.find(params[:bulk_destination_location_id])
      end
    end
  end
end
