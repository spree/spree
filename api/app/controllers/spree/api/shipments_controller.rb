module Spree
  module Api
    class ShipmentsController < Spree::Api::BaseController
      respond_to :json

      before_filter :find_order
      before_filter :find_and_update_shipment, :only => [:ship, :ready, :add, :remove]

      def create
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i
        @shipment = @order.shipments.create(:stock_location_id => params[:stock_location_id])
        @order.contents.add(variant, quantity, nil, @shipment)

        @shipment.refresh_rates
        @shipment.save!

        respond_with(@shipment.reload, :default_template => :show)
      end

      def update
        authorize! :read, Shipment
        @shipment = @order.shipments.find_by_number!(params[:id])
        params[:shipment] ||= []
        unlock = params[:shipment].delete(:unlock)

        if unlock == 'yes'
          @shipment.adjustment.open
        end

        @shipment.update_attributes(params[:shipment])

        if unlock == 'yes'
          @shipment.adjustment.close
        end

        @shipment.reload
        respond_with(@shipment, :default_template => :show)
      end

      def ready
        authorize! :read, Shipment
        unless @shipment.ready?
          if @shipment.can_ready?
            @shipment.ready!
          else
            render "spree/api/shipments/cannot_ready_shipment", :status => 422 and return
          end
        end
        respond_with(@shipment, :default_template => :show)
      end

      def ship
        authorize! :read, Shipment
        unless @shipment.shipped?
          @shipment.ship!
        end
        respond_with(@shipment, :default_template => :show)
      end

      def add
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        @order.contents.add(variant, quantity, nil, @shipment)

        respond_with(@shipment, :default_template => :show)
      end

      def remove
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        @order.contents.remove(variant, quantity, @shipment)
        @shipment.reload if @shipment.persisted?
        respond_with(@shipment, :default_template => :show)
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
