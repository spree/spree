module Spree
  module Checkout
    class SelectShippingMethod
      prepend Spree::ServiceModule::Base

      def call(order:, params:)
        shipment = order.shipments.valid.find(params[:shipment_id]) if params[:shipment_id].present?
        shipping_method = Spree::ShippingMethod.find(params[:shipping_method_id])

        # single shipment passed
        if shipment.present?
          set_shipping_rate_based_on_method(shipment: shipment, shipping_method: shipping_method)
        else
          # set shipping method for all shipments
          order.shipments.valid.each do |s|
            set_shipping_rate_based_on_method(shipment: s, shipping_method: shipping_method)
          end
        end

        success(order)
      rescue ActiveRecord::RecordNotFound => e
        failure(:selected_shipping_method_not_found, e)
      end

      def set_shipping_rate_based_on_method(shipment:, shipping_method:)
        selected_shipping_rate = shipment.shipping_rates.find_by!(shipping_method: shipping_method)

        shipment.selected_shipping_rate_id = selected_shipping_rate.id
        shipment.update_amounts
      end
    end
  end
end
