module Spree
  module Api
    module V1
      class ShipmentsController < BaseController
        before_filter :find_order
        before_filter :find_and_update_shipment, :only => [:ship, :ready]

        def ready
          @shipment.ready!
          render :show
        end

        def ship
          @shipment.ship!
          render :show
        end

        private

        def find_order
          @order = Order.find_by_number!(params[:order_id])
        end

        def find_and_update_shipment
          @shipment = @order.shipments.find_by_number!(params[:id])
          @shipment.update_attributes(params[:shipment])
        end
      end
    end
  end
end
