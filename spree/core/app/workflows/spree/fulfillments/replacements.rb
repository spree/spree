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

        fulfillments = order.pack_new_units!(units)
        failure(record, :replacement_out_of_stock) if fulfillments.nil?

        fulfillments
      end
    end
  end
end
