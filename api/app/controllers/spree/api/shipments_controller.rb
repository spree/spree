module Spree
  module Api
    class ShipmentsController < Spree::Api::BaseController

      before_action :find_and_update_shipment, only: [:ship, :ready, :add, :remove]
      before_action :load_transfer_params, only: [:transfer_to_location, :transfer_to_shipment]

      def create
        @order = Spree::Order.find_by!(number: params[:shipment][:order_id])
        authorize! :read, @order
        authorize! :create, Shipment
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i
        @shipment = @order.shipments.create(stock_location_id: params[:stock_location_id])
        @order.contents.add(variant, quantity, {shipment: @shipment})

        @shipment.save!

        respond_with(@shipment.reload, default_template: :show)
      end

      def update
        @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).find_by!(number: params[:id])
        @shipment.update_attributes_and_order(shipment_params)

        respond_with(@shipment.reload, default_template: :show)
      end

      def ready
        unless @shipment.ready?
          if @shipment.can_ready?
            @shipment.ready!
          else
            render 'spree/api/shipments/cannot_ready_shipment', status: 422 and return
          end
        end
        respond_with(@shipment, default_template: :show)
      end

      def ship
        unless @shipment.shipped?
          @shipment.ship!
        end
        respond_with(@shipment, default_template: :show)
      end

      def add
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        @shipment.order.contents.add(variant, quantity, {shipment: @shipment})

        respond_with(@shipment, default_template: :show)
      end

      def remove
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        @shipment.order.contents.remove(variant, quantity, {shipment: @shipment})
        @shipment.reload if @shipment.persisted?
        respond_with(@shipment, default_template: :show)
      end

      def transfer_to_location
        @stock_location = Spree::StockLocation.find(params[:stock_location_id])
        @original_shipment.transfer_to_location(@variant, @quantity, @stock_location)
        render json: {success: true, message: Spree.t(:shipment_transfer_success)}, status: 201
      end

      def transfer_to_shipment
        @target_shipment  = Spree::Shipment.find_by!(number: params[:target_shipment_number])
        @original_shipment.transfer_to_shipment(@variant, @quantity, @target_shipment)
        render json: {success: true, message: Spree.t(:shipment_transfer_success)}, status: 201
      end

      private

      def load_transfer_params
        @original_shipment         = Spree::Shipment.where(number: params[:original_shipment_number]).first
        @variant                   = Spree::Variant.find(params[:variant_id])
        @quantity                  = params[:quantity].to_i
        authorize! :read, @original_shipment
        authorize! :create, Shipment
      end

      def find_and_update_shipment
        @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).find_by!(number: params[:id])
        @shipment.update_attributes(shipment_params)
        @shipment.reload
      end

      def shipment_params
        if params[:shipment] && !params[:shipment].empty?
          params.require(:shipment).permit(permitted_shipment_attributes)
        else
          {}
        end
      end
    end
  end
end
