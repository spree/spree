module Spree
  module Api
    class ShipmentsController < Spree::Api::BaseController

      before_filter :find_order
      before_filter :find_and_update_shipment, only: [:ship, :ready, :add, :remove]

      def create
        authorize! :create, Shipment
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i
        @shipment = @order.shipments.create(stock_location_id: params[:stock_location_id])
        @order.contents.add(variant, quantity, nil, @shipment)

        @shipment.refresh_rates
        @shipment.save!

        render json: @shipment
      end

      def update
        @shipment = @order.shipments.accessible_by(current_ability, :update).find_by!(number: params[:id])

        unlock = params[:shipment].delete(:unlock)

        if unlock == 'yes'
          @shipment.adjustment.open
        end

        @shipment.update_attributes(shipment_params)

        if unlock == 'yes'
          @shipment.adjustment.close
        end

        @shipment.reload
        render json: @shipment
      end

      def ready
        unless @shipment.ready?
          if @shipment.can_ready?
            @shipment.ready!
          else
            render json: {
              error: I18n.t(:cannot_ready, :scope => "spree.api.shipment")
              }, status: 422
            return
          end
        end
        render json: @shipment
      end

      def ship
        unless @shipment.shipped?
          @shipment.ship!
        end
        render json: @shipment
      end

      def add
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        @order.contents.add(variant, quantity, nil, @shipment)

        render json: @shipment
      end

      def remove
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        @order.contents.remove(variant, quantity, @shipment)
        @shipment.reload if @shipment.persisted?
        render json: @shipment
      end

      private

      def find_order
        @order = Spree::Order.find_by!(number: params[:order_id])
        authorize! :read, @order
      end

      def find_and_update_shipment
        @shipment = @order.shipments.accessible_by(current_ability, :update).find_by!(number: params[:id])
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
