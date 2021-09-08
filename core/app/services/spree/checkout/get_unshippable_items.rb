module Spree
  module Checkout
    class GetUnshippableItems
      prepend Spree::ServiceModule::Base

      def call(order:)
        run :reload_order
        run :ensure_shipping_address
        run :ensure_line_items_present
        run :return_unshippable_items
      end

      private

      def reload_order(order:)
        success(order: order.reload)
      end

      def ensure_shipping_address(order:)
        return failure([], Spree.t('errors.services.get_unshippable_items.no_shipping_address')) if order.ship_address.blank?

        success(order: order)
      end

      def ensure_line_items_present(order:)
        return failure([], Spree.t('errors.services.get_shipping_rates.no_line_items')) if order.line_items.empty?

        success(order: order)
      end

      def return_unshippable_items(order:)
        success(unshippable_items(order: order))
      end

      protected

      def unshippable_items(order:)
        # TODO: Use `order.store.checkout_zone`
        shipping_address_zone_id = Spree::Zone.match(order.shipping_address)&.id
        return [] if shipping_address_zone_id.nil?

        order.line_items.select do |item|
          item.variant.shipping_category.shipping_methods.any? do |sm|
            sm.zone_ids.exclude?(shipping_address_zone_id)
          end
        end
      end
    end
  end
end
