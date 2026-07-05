# adds item to an existing shipment
# if this variant is already added to the cart it will increase the quantity
# if not it will create new line item
module Spree
  module Shipments
    class AddItem
      prepend Spree::ServiceModule::Base
      include Helper

      def call(shipment:, variant_id:, quantity: nil)
        ActiveRecord::Base.transaction do
          run :prepare_arguments
          run :add_or_update_line_item
        end
      end

      protected

      def prepare_arguments(shipment:, variant_id:, quantity: nil)
        order = shipment.order
        store = order.store

        variant = store.variants.find_by(id: variant_id)
        return failure(nil, :variant_not_found) if variant.nil?

        quantity = quantity&.to_i || 1

        success(order: order, shipment: shipment, variant: variant, quantity: quantity)
      end
    end
  end
end
