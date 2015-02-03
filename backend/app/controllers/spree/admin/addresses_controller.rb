module Spree
  module Admin
    class AddressesController < ResourceController

      def create_shipment_address
        @address = Spree::Address.new(address_params)
        shipment = Spree::Shipment.find(params[:shipment_id])

        if @address.save
          shipment.update_attributes address_id: @address.id
          flash[:success] = flash_message_for(@address, :successfully_created)
        else
          flash[:error] = @address.errors.full_messages.join(", ")
        end

        respond_with(shipment.order) do |format|
          format.html { redirect_to edit_admin_order_path(shipment.order) }
          format.js   { render layout: false }
        end
      end

      private

        def address_params
          params.require(:address).permit(permitted_address_attributes)
        end
    end
  end
end
