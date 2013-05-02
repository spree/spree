module Spree
  module Admin
    class StockTransfersController < ResourceController

      def collection
        collection = StockTransfer.includes(:stock_movements => { :stock_item => :stock_location })
                       .order('created_at DESC')
                       .page(params[:page])

        if params.has_key? :source_location_id
          collection = collection.where(:source_location_id => params[:source_location_id])
        end

        if params.has_key? :destination_location_id
          collection = collection.where(:destination_location_id => params[:destination_location_id])
        end

        collection
      end
    end
  end
end
