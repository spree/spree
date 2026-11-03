module Spree
  module Returns
    # How many units of a shipped item can still go back.
    #
    # A return and an exchange both take the same units off the customer, so
    # each counts the other: without that, the units a customer returned could
    # be exchanged again, and the credit for the exchange paid out a second
    # time. Units named twice in one request count twice too.
    module ReturnableQuantity
      extend ActiveSupport::Concern

      # Units already promised back, per fulfillment item — every return and
      # exchange line that is not canceled, in two queries however many items
      # are asked about.
      #
      # @param fulfillment_item_ids [Array<Integer>]
      # @return [Hash{Integer => Integer}] fulfillment item id => units
      def self.claimed_quantities(fulfillment_item_ids)
        return {} if fulfillment_item_ids.empty?

        returned = Spree::ReturnLineItem.
                   joins(:return).
                   where(fulfillment_item_id: fulfillment_item_ids).
                   where.not(Spree::Return.table_name => { status: 'canceled' }).
                   group(:fulfillment_item_id).
                   sum(:quantity)
        exchanged = Spree::ExchangeLineItem.
                    joins(:exchange).
                    where(fulfillment_item_id: fulfillment_item_ids).
                    where.not(Spree::Exchange.table_name => { status: 'canceled' }).
                    group(:fulfillment_item_id).
                    sum(:quantity)

        returned.merge(exchanged) { |_id, returned_units, exchanged_units| returned_units + exchanged_units }
      end

      private

      # Checks each item's quantity against what is still returnable and
      # fails with the item's name when it is not.
      #
      # @param items [Array<Hash>] `[{ fulfillment_item:, quantity: }]`
      # @param action [String] 'returned' or 'exchanged', for the message
      def ensure_returnable_quantities(items, action:)
        requested = Hash.new(0)
        claimed = Spree::Returns::ReturnableQuantity.claimed_quantities(items.map { |item| item[:fulfillment_item].id })

        items.each do |item|
          fulfillment_item = item[:fulfillment_item]
          available = fulfillment_item.quantity.to_i - claimed.fetch(fulfillment_item.id, 0) - requested[fulfillment_item.id]
          if item[:quantity] > available
            failure(order, "Only #{[available, 0].max} of #{fulfillment_item.variant.name} can be #{action}")
          end

          requested[fulfillment_item.id] += item[:quantity]
        end
      end
    end
  end
end
