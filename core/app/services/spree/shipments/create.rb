# creates new shipment record
# if selected item (variant) is already added to order it will update line item
# if not - it will create new line item record
module Spree
  module Shipments
    class Create
      prepend Spree::ServiceModule::Base
      include Helper

      def call(store:, shipment_attributes:)
        ActiveRecord::Base.transaction do
          run :prepare_arguments
          run :create_shipment
          run :add_or_update_line_item
        end
      end

      protected

      def prepare_arguments(store:, shipment_attributes:)
        order_id_or_number = shipment_attributes[:order_id]
        order = store.orders.find_by(number: order_id_or_number) || store.orders.find_by(id: order_id_or_number)

        return failure(nil, :order_not_found) if order.nil?

        variant = store.variants.find_by(id: shipment_attributes[:variant_id])
        return failure(nil, :variant_not_found) if variant.nil?

        stock_location = Spree::StockLocation.find_by(id: shipment_attributes[:stock_location_id])
        return failure(nil, :stock_location_not_found) if stock_location.nil?

        quantity = shipment_attributes[:quantity]&.to_i || 1

        success(order: order, stock_location: stock_location, variant: variant, quantity: quantity)
      end

      def create_shipment(order:, stock_location:, variant:, quantity:)
        shipment = order.shipments.create(
          order_id: order.id,
          stock_location_id: stock_location.id
        )
        return failure(shipment) unless shipment.persisted?

        success(order: order, variant: variant, quantity: quantity, shipment: shipment)
      end
    end
  end
end
