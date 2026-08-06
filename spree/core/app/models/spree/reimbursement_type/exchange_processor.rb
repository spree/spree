module Spree
  class ReimbursementType
    # Legacy exchange execution for the ReturnAuthorization/Reimbursement
    # chain. Renamed out of Spree::Exchange, which is now the first-class
    # exchange model (docs/plans/6.0-returns-exchanges-claims.md); this stays
    # until that chain is dropped.
    class ExchangeProcessor
      class UnableToCreateShipments < StandardError; end

      def initialize(order, reimbursement_objects)
        @order = order
        @reimbursement_objects = reimbursement_objects
      end

      def description
        @reimbursement_objects.map do |reimbursement_object|
          "#{reimbursement_object.variant.options_text} => #{reimbursement_object.exchange_variant.options_text}"
        end.join(' | ')
      end

      def display_amount
        Spree::Money.new @reimbursement_objects.sum(&:total)
      end

      def perform!
        new_exchange_inventory_units = @reimbursement_objects.map(&:build_default_exchange_inventory_unit)
        shipments = Spree::Stock::Coordinator.new(@order, new_exchange_inventory_units).fulfillments
        shipments_units = shipments.flat_map(&:fulfillment_items)

        if shipments_units.sum(&:quantity) != new_exchange_inventory_units.sum(&:quantity)
          raise UnableToCreateShipments, 'Could not generate shipments for all items. Out of stock?'
        end

        @order.fulfillments += shipments
        @order.save!

        shipments.each do |shipment|
          shipment.update!(@order)
          shipment.finalize!
        end
      end

      def to_key
        nil
      end

      def self.param_key
        'spree_exchange'
      end

      def self.model_name
        Spree::ReimbursementType::ExchangeProcessor
      end
    end
  end
end
