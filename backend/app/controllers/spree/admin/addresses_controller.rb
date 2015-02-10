module Spree
  module Admin
    class AddressesController < ResourceController
      def create_shipment
        @address = Spree::Address.new(address_params)
        @shipment = Spree::Shipment.find(params[:shipment_id])

        if @address.save
          update_shipment_address(@shipment, @address)
          flash[:success] = flash_message_for(@address, :successfully_created)
          apply_to_other_shipment
        else
          flash[:error] = @address.errors.full_messages.join(", ")
        end

        respond_with(@shipment.order) do |format|
          format.html { redirect_to edit_admin_order_path(@shipment.order) }
          format.js   { render layout: false }
        end
      end

      private

      def update_shipment_address(shipment, address)
        shipment.update_attributes address_id: address.id
      end

      def address_params
        params.require(:address).permit(permitted_address_attributes)
      end

      def apply_to_other_shipment
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
