module Spree
  module Admin
    class AddressesController < ResourceController
      before_action :load_shipment, only: :create_shipment
      before_action :load_address, only: :create_shipment

      def create_shipment
        @address.attributes = address_params

        if @shipment.save
          apply_to_other_shipments
          flash[:success] = flash_message_for(@address, :successfully_created)
        else
          flash[:error] = @address.errors.full_messages.join(", ")
        end

        respond_with(@shipment.order) do |format|
          format.html { redirect_to edit_admin_order_path(@shipment.order) }
          format.js   { render layout: false }
        end
      end

      private

      def load_shipment
        @shipment = Spree::Shipment.find(params[:shipment_id])
      end

      def load_address
        # Build address for shipment if shipment address not present
        # OR if shipment address is same as order ship address
        # ELSE load existing shipment address
        @address = if @shipment.address && @shipment.address != @shipment.order.ship_address
          @shipment.address
        else
          @shipment.build_address
        end
      end

      def update_shipment_address(shipment, address)
        shipment.update_attributes address_id: address.id
      end

      def address_params
        params.require(:address).permit(permitted_address_attributes)
      end

      def apply_to_other_shipments
        if other_shipments = params[:apply_to_other_shipments]
          other_shipments.each do |shipment_id|
            shipment = Spree::Shipment.find(shipment_id)
            update_shipment_address shipment, @address
          end
        end
      end
    end
  end
end
