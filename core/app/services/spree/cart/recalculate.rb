module Spree
  module Cart
    class Recalculate
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, line_item_created: false, options: {})
        order_updater = order.updater

        order.remove_gift_card if order.gift_card.present?
        order.payments.store_credits.checkout.destroy_all if order.payments.store_credits.checkout.any?
        order_updater.update_totals
        order_updater.persist_totals

        shipment = options[:shipment]
        if shipment.present?
          # ADMIN END SHIPMENT RATE FIX
          # refresh shipments to ensure correct shipment amount is calculated when using price sack calculator
          # for calculating shipment rates.
          # Currently shipment rate is calculated on previous order total instead of current order total when updating a shipment from admin end.
          order.refresh_shipment_rates(::Spree::ShippingMethod::DISPLAY_ON_BACK_END)
          shipment.update_amounts
        else
          order.ensure_updated_shipments
        end

        ::Spree::PromotionHandler::Cart.new(order, line_item).activate
        ::Spree::Adjustable::AdjustmentsUpdater.update(line_item)
        ::Spree::TaxRate.adjust(order, [line_item.reload]) if line_item_created
        order_updater.update
        success(line_item)
      end
    end
  end
end
