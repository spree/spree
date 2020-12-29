module Spree
  module Checkout
    class GetShippingRates
      prepend Spree::ServiceModule::Base

      def call(order:)
        run :reload_order
        run :ensure_shipping_address
        run :ensure_line_items_present
        run :generate_or_return_shipping_rates
      end

      private

      # we need to reload order to fetch the most up-to-date version of it
      def reload_order(order:)
        success(order: order.reload)
      end

      def ensure_shipping_address(order:)
        return failure([], Spree.t('errors.services.get_shipping_rates.no_shipping_address')) if order.ship_address.blank?

        success(order: order)
      end

      def ensure_line_items_present(order:)
        return failure([], Spree.t('errors.services.get_shipping_rates.no_line_items')) if order.line_items.empty?

        success(order: order)
      end

      def generate_or_return_shipping_rates(order:)
        generate_shipping_rates(order: order) if order.shipments.empty?
        return_shipments(order: order)
      end

      def generate_shipping_rates(order:)
        ApplicationRecord.transaction do
          order.create_proposed_shipments
          order.create_shipment_tax_charge!
          order.set_shipments_cost
          order.apply_free_shipping_promotions
        end
        success(order: order.reload)
      end

      def return_shipments(order:)
        success(order.reload.shipments.includes([shipping_rates: :shipping_method]))
      end
    end
  end
end
