module Spree
  module Checkout
    class Update
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      def call(order:, params:, permitted_attributes:, request_env:)
        ship_changed = address_with_country_iso_present?(params, 'ship')
        bill_changed = address_with_country_iso_present?(params, 'bill')
        params[:order][:ship_address_attributes] = replace_country_iso_with_id(params[:order][:ship_address_attributes]) if ship_changed
        params[:order][:bill_address_attributes] = replace_country_iso_with_id(params[:order][:bill_address_attributes]) if bill_changed
        order.state = 'address' if (ship_changed || bill_changed) && order.has_checkout_step?('address')
        order.state = 'delivery' if selected_shipping_rate_present?(params) && order.has_checkout_step?('delivery')
        return success(order) if order.update_from_params(params, permitted_attributes, request_env)

        failure(order)
      end

      private

      def address_with_country_iso_present?(params, address_kind = 'ship')
        return false unless params.dig(:order, "#{address_kind}_address_attributes".to_sym, :country_iso)
        return false if params.dig(:order, "#{address_kind}_address_attributes".to_sym, :country_id)

        true
      end

      def selected_shipping_rate_present?(params)
        shipments_attributes = params.dig(:order, :shipments_attributes)
        return false unless shipments_attributes

        shipments_attributes.any? { |s| s.dig(:selected_shipping_rate_id) }
      end
    end
  end
end
