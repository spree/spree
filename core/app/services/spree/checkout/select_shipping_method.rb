module Spree
  module Checkout
    # @deprecated This service is deprecated and will be removed in Spree 6.0.
    #   Order totals are now automatically updated via a callback on ShippingRate
    #   when selected_shipping_rate_id is set on a Shipment.
    class SelectShippingMethod
      prepend Spree::ServiceModule::Base

      def call(order:, params:)
        Spree::Deprecation.warn(
          "#{self.class.name} is deprecated and will be removed in Spree 6.0. " \
          "Order totals are now automatically updated via ShippingRate callback when " \
          "selected_shipping_rate_id is set on a Shipment.",
          caller_locations(2)
        )
        if params[:shipment_id].present?
          shipment = order.shipments.valid.find_by(id: params[:shipment_id])
          return failure(:shipment_not_found) if shipment.nil?
        end

        shipping_method = Spree::ShippingMethod.find_by(id: params[:shipping_method_id])
        return failure(:shipping_method_not_found) if shipping_method.nil?

        # single shipment passed
        if shipment.present?
          result = set_shipping_rate_based_on_method(shipment: shipment, shipping_method: shipping_method)

          return failure(result.value, result.error) unless result.success?
        else
          # set shipping method for all shipments
          order.shipments.valid.each do |s|
            result = set_shipping_rate_based_on_method(shipment: s, shipping_method: shipping_method)

            return failure(result.value, result.error) unless result.success?
          end
        end

        # Note: selected_shipping_rate_id= now automatically updates order totals,
        # but we still need update_with_updater! here because Checkout::Advance
        # expects the full updater to run (including state updates) when this service succeeds.
        order.update_with_updater!

        success(order)
      end

      def set_shipping_rate_based_on_method(shipment:, shipping_method:)
        selected_shipping_rate = shipment.shipping_rates.find_by(shipping_method: shipping_method)

        if selected_shipping_rate.nil?
          return failure(
            :selected_shipping_method_not_found,
            "Couldn't find shipping rates for Shipping Method with ID = #{shipping_method.id} and Shipment with ID = #{shipment.id}"
          )
        end

        # selected_shipping_rate_id= now automatically calls update_amounts and updates order totals
        shipment.selected_shipping_rate_id = selected_shipping_rate.id

        success(shipment)
      end
    end
  end
end
