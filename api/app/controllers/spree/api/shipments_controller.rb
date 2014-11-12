module Spree
  module Api
    class ShipmentsController < Spree::Api::BaseController

      before_filter :find_and_update_shipment, only: [:ship, :ready, :add, :remove]

      def create
        @order = Spree::Order.find_by!(number: params.fetch(:shipment).fetch(:order_id))
        authorize! :read, @order
        authorize! :create, Shipment
        quantity = params[:quantity].to_i
        @shipment = @order.shipments.create(stock_location_id: params.fetch(:stock_location_id))
        @order.contents.add(variant, quantity, nil, @shipment)

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
        quantity = params[:quantity].to_i

        @shipment.order.contents.add(variant, quantity, nil, @shipment)

        respond_with(@shipment, default_template: :show)
      end

      def remove
        quantity = params[:quantity].to_i

        @shipment.order.contents.remove(variant, quantity, @shipment)
        @shipment.reload if @shipment.persisted?
        respond_with(@shipment, default_template: :show)
      end

      private

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

      def variant
        @variant ||= Spree::Variant.unscoped.find(params.fetch(:variant_id))
      end
    end
  end
end
