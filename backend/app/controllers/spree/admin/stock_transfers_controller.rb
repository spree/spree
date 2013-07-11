module Spree
  module Admin
    class StockTransfersController < Admin::BaseController
      before_filter :load_stock_locations, :only => :index

      def index
        @q = StockTransfer.search(params[:q])

        @stock_transfers = @q.result
                             .includes(:stock_movements => { :stock_item => :stock_location })
                             .order('created_at DESC')
                             .page(params[:page])
      end

      def show
        @stock_transfer = StockTransfer.find_by_param(params[:id])
      end

      def new

      end

      def create
        variants = Hash.new(0)
        params[:variant].each_with_index do |variant_id, i|
          variants[variant_id] += params[:quantity][i].to_i
        end

        stock_transfer = StockTransfer.create(:reference => params[:reference])
        stock_transfer.transfer(source_location,
                                destination_location,
                                variants)

        flash[:success] = Spree.t(:stock_successfully_transferred)
        redirect_to admin_stock_transfer_path(stock_transfer)
      end

      private
      def load_stock_locations
        @stock_locations = Spree::StockLocation.active.order('name ASC')
      end

      def source_location
        @source_location ||= params.has_key?(:transfer_receive_stock) ? nil :
                               StockLocation.find(params[:transfer_source_location_id])
      end

      def destination_location
        @destination_location ||= StockLocation.find(params[:transfer_destination_location_id])
      end
    end
  end
end
