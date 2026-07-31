# Update a Fulfillment and make sure the owning Order's totals and
# statuses follow the fulfillment changes
module Spree
  module Fulfillments
    class Update
      prepend Spree::ServiceModule::Base

      def call(fulfillment: nil, fulfillment_attributes: nil, shipment: nil, shipment_attributes: nil)
        if shipment || shipment_attributes
          Spree::Deprecation.warn(
            'Calling Spree::Fulfillments::Update with shipment:/shipment_attributes: keywords is deprecated ' \
            'and will be removed in Spree 6.1. Use fulfillment:/fulfillment_attributes: instead.'
          )
          fulfillment ||= shipment
          fulfillment_attributes ||= shipment_attributes
        end
        fulfillment_attributes ||= {}

        ActiveRecord::Base.transaction do
          return failure(fulfillment) unless fulfillment.update(fulfillment_attributes)

          if fulfillment_attributes.key?(:selected_shipping_rate_id) || fulfillment_attributes.key?(:selected_delivery_rate_id)
            order = fulfillment.order

            # Changing the selected Delivery Rate won't update the cost (for now)
            # so we persist the Fulfillment#cost before calculating order delivery
            # total and updating payment status (given a change in fulfillment cost
            # might change the Order#payment_status)
            fulfillment.update_amounts

            order.recalculate_totals!

            # Update fulfillment status only after order total is updated because it
            # (via Order#paid?) affects the fulfillment status (YAY)
            fulfillment.update_columns(
              status: fulfillment.determine_state(order),
              updated_at: Time.current
            )

            # And then derive the order-level statuses from the new status
            order.update_statuses!
          end
        end
        success(fulfillment)
      end
    end
  end
end
