# removes an item (variant) from shipment
# quantity can be passed
# if there is no quantity left for this item for this shipent, shipment itself will be removed
module Spree
  module Shipments
    class RemoveItem
      prepend Spree::ServiceModule::Base
      include Helper

      def call(shipment:, variant_id:, quantity: nil)
        ActiveRecord::Base.transaction do
          run :prepare_arguments
          run :remove_item
        end
      end

      protected

      def prepare_arguments(shipment:, variant_id:, quantity: nil)
        variant = Spree::Variant.find_by(id: variant_id)
        return failure(nil, :variant_not_found) if variant.nil? || !shipment.include?(variant)

        # if quantity isn't passed let's remove all added qty of this variant
        quantity = quantity&.to_i || shipment.inventory_units_for(variant).sum(:quantity)

        success(shipment: shipment, variant: variant, quantity: quantity)
      end

      # if the removed variant was the only one shipped via this shipment
      # we need to remove the shipment itself
      def remove_item(shipment:, variant:, quantity:)
        result = remove_item_service.call(order: shipment.order,
                                          variant: variant,
                                          quantity: quantity,
                                          options: { shipment: shipment })

        if result.success?
          line_item = result.value
          line_item.destroy if line_item.quantity.zero?

          # `OrderInventory#remove_from_shipment` is called in `remove_item_service`
          # which will delete the shipment if all inventory units were removed
          if shipment.inventory_units.any?
            success(shipment)
          else
            shipment.destroy!
            success(:shipment_deleted)
          end
        else
          failure(result.value, result.error)
        end
      end
    end
  end
end
