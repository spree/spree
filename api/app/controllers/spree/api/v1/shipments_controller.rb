module Spree
  module Api
    module V1
      class ShipmentsController < Spree::Api::BaseController
        before_filter :find_order
        before_filter :find_and_update_shipment, :only => [:ship, :ready]

        def ready
          authorize! :read, Shipment
          unless @shipment.ready?
            @shipment.ready!
          end
          render :show
        end

        def ship
          authorize! :read, Shipment
          unless @shipment.shipped?
            @shipment.ship!
          end
          render :show
        end

        private

        def find_order
          @order = Spree::Order.find_by_number!(params[:order_id])
          authorize! :read, @order
        end

        def find_and_update_shipment
          @shipment = @order.shipments.find_by_number!(params[:id])
          @shipment.update_attributes(params[:shipment])
          @shipment.reload
        end
      end
    end
  end
end
