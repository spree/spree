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

        # for quick checkouts we cannot revert to previous states
        # we already have the address and delivery steps completed
        # however we need to update the shipping address with missing data
        # as previously we didn't have access to first/last name and street
        unless params[:do_not_change_state]
          order.state = 'address' if (ship_changed || bill_changed || quick_checkout_cancelled?(params)) && order.has_checkout_step?('address')
          order.state = 'delivery' if selected_shipping_rate_present?(params) && order.has_checkout_step?('delivery')
        end

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

      def quick_checkout_cancelled?(params)
        params.dig(:order, :ship_address_id) == 'CLEAR'
      end
    end
  end
end
