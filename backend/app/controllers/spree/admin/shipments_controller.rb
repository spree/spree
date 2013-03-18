module Spree
  module Admin
    class ShipmentsController < Spree::Admin::BaseController
      respond_to :html

      before_filter :order_counter, :only => [:index, :review, :new]

      def index
        @shipments = order.shipments
      end

      def review
        @order = order
        @locations = Spree::StockLocation.active
      end

      def new
        stock_location = Spree::StockLocation.find_by_id(params[:stock_location])
        unless stock_location and order_counter.remaining?
          return redirect_to review_admin_order_shipments_path(order)
        end

        package = Stock::Package.new(stock_location, order)
        order_counter.variants_with_remaining.each do |variant|
          package.add variant, order_counter.remaining(variant), :on_hand
        end

        @shipment = package.to_shipment

        estimator = Stock::Estimator.new(order)
        @shipment.shipping_rates = estimator.shipping_rates(package)

        @shipment.save!

        redirect_to edit_admin_order_shipment_path(order, @shipment)
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

      def order_counter
        @order_counter ||= Stock::OrderCounter.new(order)
      end

      def shipment
        @shipment ||= order.shipments.find_by_number(params[:id])
      end

      def model_class
        Spree::Shipment
      end
    end
  end
end
