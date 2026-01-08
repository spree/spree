module Spree
  module Checkout
    class Update
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      def call(order:, params:, permitted_attributes:, request_env:)
        # Validate address ownership to prevent IDOR attacks
        address_ownership_error = validate_address_ownership(order, params)
        return failure(order, address_ownership_error) if address_ownership_error

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

      def validate_address_ownership(order, params)
        return nil unless params[:order]

        %w[bill ship].each do |address_kind|
          address_id = params[:order].dig("#{address_kind}_address_attributes".to_sym, :id)
          next unless address_id

          address = Spree::Address.find_by(id: address_id)
          next unless address

          # Allow if address has no user (guest address) or belongs to the order's user
          next if address.user_id.nil?
          next if order.user_id.present? && address.user_id == order.user_id

          return Spree.t(:address_not_owned_by_user)
        end

        nil
      end

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
