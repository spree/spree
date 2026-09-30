# frozen_string_literal: true

module Spree
  module Fulfillments
    # Sends replacement goods for an exchange or a claim.
    #
    # Replacement units hang off the line they replace but are flagged, so an
    # edit of that line counts only what the customer bought — otherwise the
    # replacement reads as a unit the line already holds, and raising the
    # quantity adds nothing.
    module Replacements
      extend ActiveSupport::Concern

      private

      def build_replacements(record, items)
        order = record.order

        # By id, not through the association writers: with has_many inversing
        # each writer adds the template to its owner's collection, and the
        # owner's next save persists it beside the packed copy.
        units = items.map do |item|
          Spree::FulfillmentItem.new(
            order_id: order.id,
            line_item_id: item[:line_item].id,
            variant_id: item[:variant].id,
            quantity: item[:quantity],
            status: 'on_hand',
            replacement: true
          )
        end

        fulfillments = Spree::Stock::Coordinator.new(order, units).fulfillments
        if fulfillments.flat_map(&:fulfillment_items).sum(&:quantity) != units.sum(&:quantity)
          failure(record, :replacement_out_of_stock)
        end

        order.fulfillments += fulfillments
        order.save!
        fulfillments.each { |fulfillment| allocate_replacement_stock(fulfillment) }
        fulfillments
      end

      # The replacement is promised the moment it exists, exactly as placement
      # promises an order's own fulfillments. Without this the fulfillment holds
      # nothing, and dispatch then writes no movement at all — an unallocated
      # fulfillment is indistinguishable from one created before typed
      # movements, so the goods would leave the shelf untouched and unrecorded.
      def allocate_replacement_stock(fulfillment)
        fulfillment.manifest.each do |item|
          next unless item.variant.track_inventory?
          next unless item.quantity.positive?

          fulfillment.stock_location.allocate(item.variant, item.quantity, fulfillment)
        end
      end
    end
  end
end
