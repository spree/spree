# Update Shipment and make sure Order states follow the shipment changes
module Spree
  module Shipments
    class Update
      prepend Spree::ServiceModule::Base

      def call(shipment:, shipment_attributes: {})
        ActiveRecord::Base.transaction do
          return failure(shipment) unless shipment.update(shipment_attributes)

          if shipment_attributes.key?(:selected_shipping_rate_id)
            order = shipment.order

            # Changing the selected Shipping Rate won't update the cost (for now)
            # so we persist the Shipment#cost before calculating order shipment
            # total and updating payment state (given a change in shipment cost
            # might change the Order#payment_state)
            shipment.update_amounts

            order.updater.update_shipment_total
            order.updater.update_payment_state

            # Update shipment state only after order total is updated because it
            # (via Order#paid?) affects the shipment state (YAY)
            shipment.update_columns(
              state: shipment.determine_state(order),
              updated_at: Time.current
            )

            # And then it's time to update shipment states and finally persist
            # order changes
            order.updater.update_shipment_state
            order.updater.persist_totals
          end
        end
        success(shipment)
      end
    end
  end
end
