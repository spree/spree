module Spree
  module Admin
    module ShipmentsHelper
      def change_shipment_address_button(shipment, order)
        button_and_modal = ""

        if shipment.address && shipment.address != order.ship_address
          button_text = Spree.t(:change_shipment_address)
          action_type = :update
        else
          button_text = Spree.t(:new_shipment_address)
          action_type = :new
        end

        # render a button
        button_and_modal << button_tag(button_text,
               data: {
                 toggle: "modal",
                 target: "##{action_type}_address_#{ shipment.id }"
               },
               class: "btn btn-success btn-sm js-shipment-address-modal")

        # render the shipment modal which shows at button click
        button_and_modal << render(partial: "spree/admin/orders/shipment_address_modal",
               locals: {
                 shipment: shipment,
                 type: action_type,
                 url: admin_shipment_address_path(shipment.id)
               })

        button_and_modal.html_safe
      end
    end
  end
end
