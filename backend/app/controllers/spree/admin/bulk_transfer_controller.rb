module Spree
  module Admin
    class BulkTransferController < Spree::Admin::BaseController

      def index
        @stock_locations = StockLocation.active
        @variants = Variant.all
      end

      def transfer
        variants = {}
        params[:variant].each_with_index do |variant_id, i|
          variants[variant_id] = params[:quantity][i].to_i
        end

        stock_transfer = StockTransfer.create(:reference_number => params[:reference_number])
        stock_transfer.transfer(source_location,
                                destination_location,
                                variants)

        flash[:success] = t(:transfer_successful)
        redirect_to :action => :index
      end

      private
      def source_location
        @source_location ||= params.has_key?(:bulk_receive_stock) ? nil :
                               StockLocation.find(params[:source_location_id])
      end

      def destination_location
        @destination_location ||= StockLocation.find(params[:source_location_id])
      end
    end
  end
end
