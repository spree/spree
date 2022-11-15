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
        if order.update_from_params(params, permitted_attributes, request_env)
          notify_order_stream(order: order, params: params, permitted_attributes: permitted_attributes)
          return success(order)
        end

        failure(order)
      end

      private

      def notify_order_stream(order:, params:, permitted_attributes:)
        # retrieve proper states
        Rails.configuration.event_store.publish(
          ::Checkout::Event::UpdateOrder.new(data: { order: order.as_json, prev_state: order.state, next_state: order.state, payload: params }), stream_name: "customer_#{order.email}"
        )

        success(order)
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
