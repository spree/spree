module Spree
  module Admin
    class AddressesController < ResourceController
      before_action :load_shipment, only: :attach_shipment
      before_action :load_address, only: :attach_shipment

      def attach_shipment
        @address.attributes = address_params

        if @shipment.save
          apply_to_other_shipments
          flash[:success] = flash_message_for(@shipment, :successfully_updated)

          respond_with(@shipment.order) do |format|
            format.html { redirect_to edit_admin_order_path(@shipment.order) }
            format.js { render js: "window.location = '#{edit_admin_order_path(@shipment.order)}'" }
          end
        else
          respond_with(@shipment.order) do |format|
            format.html do
              flash[:error] = @address.errors.full_messages.join(", ")
              redirect_to edit_admin_order_path(@shipment.order)
            end

            format.js { render layout: false }
          end
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
        @address = if @shipment.address && @shipment.address.id != @shipment.order.ship_address.try(:id)
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
