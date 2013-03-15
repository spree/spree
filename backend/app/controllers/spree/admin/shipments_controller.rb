module Spree
  module Admin
    class ShipmentsController < Spree::Admin::BaseController
      respond_to :html

      def index
        @shipments = order.shipments
      end

      def review
        @order = order
        @locations = Spree::StockLocation.active
      end

      def new
        stock_location = Spree::StockLocation.find_by_id(params[:stock_location])
        redirect_to review_admin_order_shipments_path(order) unless stock_location

        #TODO build shipment from location and populate with needed stock
        build_shipment
      end

      def create
        build_shipment
        assign_inventory_units
        if shipment.save
          flash[:success] = flash_message_for(shipment, :successfully_created)
          redirect_to edit_admin_order_shipment_path(order, shipment)
        else
          render :action => 'new'
        end
      end

      def edit
        shipment.special_instructions = order.special_instructions
      end

      def update
        assign_inventory_units
        if shipment.update_attributes params[:shipment]
          # copy back to order if instructions are enabled
          order.special_instructions = params[:shipment][:special_instructions] if Spree::Config[:shipping_instructions]
          order.shipping_method = order.shipment.shipping_method
          order.save

          flash[:success] = flash_message_for(shipment, :successfully_updated)
          return_path = order.completed? ? edit_admin_order_shipment_path(order, shipment) : admin_order_adjustments_path(order)
          redirect_to return_path
        else
          render :action => 'edit'
        end
      end

      def destroy
        shipment.destroy
        respond_with(shipment) { |format| format.js { render_js_for_destroy } }
      end

      def fire
        if shipment.send("#{params[:e]}")
          flash[:success] = t(:shipment_updated)
        else
          flash[:error] = t(:cannot_perform_operation)
        end

        redirect_to :back
      end

      private
      def assign_inventory_units
        return unless params.has_key? :inventory_units
        shipment.inventory_unit_ids = params[:inventory_units].keys
      end

      def order
        @order ||= Order.find_by_number(params[:order_id])
        authorize! action, @order
      end

      def shipment
        @shipment ||= order.shipments.find_by_number(params[:id])
      end

      def build_shipment
        @shipment = order.shipments.build
        @shipment.address ||= order.ship_address
        @shipment.address ||= Address.new(:country_id => Spree::Config[:default_country_id])
        @shipment.attributes = params[:shipment]
      end

      def model_class
        Spree::Shipment
      end
    end
  end
end
