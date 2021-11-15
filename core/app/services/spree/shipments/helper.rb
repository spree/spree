module Spree
  module Shipments
    module Helper
      def add_or_update_line_item(order:, variant:, quantity:, shipment:)
        result = add_item_service.call(order: order, variant: variant, quantity: quantity, options: { shipment: shipment })

        if result.success?
          success(shipment.reload)
        else
          failure(result.value, result.error)
        end
      end

      def add_item_service
        Spree::Dependencies.cart_add_item_service.constantize
      end

      def remove_item_service
        Spree::Dependencies.cart_remove_item_service.constantize
      end
    end
  end
end
