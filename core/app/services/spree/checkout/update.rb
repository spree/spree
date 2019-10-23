module Spree
  module Checkout
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params:, permitted_attributes:, request_env:)
        params = replace_country_iso_with_id(params, 'ship') if address_with_country_iso_present?(params, 'ship')
        params = replace_country_iso_with_id(params, 'bill') if address_with_country_iso_present?(params, 'bill')
        return success(order) if order.update_from_params(params, permitted_attributes, request_env)

        failure(order)
      end

      private

      def address_with_country_iso_present?(params, address_kind = 'ship')
        return false unless params.dig(:order, "#{address_kind}_address_attributes".to_sym, :country_iso)
        return false if params.dig(:order, "#{address_kind}_address_attributes".to_sym, :country_id)

        true
      end

      def replace_country_iso_with_id(params, address_kind = 'ship')
        country_id = Spree::Country.by_iso(params[:order]["#{address_kind}_address_attributes"].fetch(:country_iso))&.id

        params[:order]["#{address_kind}_address_attributes"]['country_id'] = country_id
        params[:order]["#{address_kind}_address_attributes"].delete(:country_iso)
        params
      end
    end
  end
end
