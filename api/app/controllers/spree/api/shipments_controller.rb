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
        @shipment.add(variant, quantity)

        estimator = Stock::Estimator.new(@order)
        @shipment.shipping_rates = estimator.shipping_rates(@shipment.to_package)
        rate = @shipment.shipping_rates.first
        rate.selected = true
        rate.save!
        @shipment.save!

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

        @shipment.add(variant, quantity)

        respond_with(@shipment, :default_template => :show)
      end

      def remove
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        #create stock_movement
        @shipment.stock_location.move variant.id, -quantity, @shipment

        #update line_item
        line_item = @order.find_line_item_by_variant(variant)
        line_item.quantity += -quantity

        if line_item.quantity == 0
          line_item.destroy
        else
          line_item.save!
        end

        #destroy inventory_units
        variant_units = @shipment.inventory_units.group_by(&:variant_id)
        if variant_units.include? variant.id

          variant_units = variant_units[variant.id].reject do |variant_unit|
            variant_unit.state == 'shipped'
          end.sort_by(&:state)

          quantity.times do
            inventory_unit = variant_units.shift
            inventory_unit.destroy
          end
        else
          #raise exception variant does not belong to shipment
        end

        @shipment.reload
        @shipment.order.update!

        if @shipment.reload.inventory_units.size == 0
          @shipment.destroy
        end

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
