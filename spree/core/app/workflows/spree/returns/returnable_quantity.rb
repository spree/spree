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

      private

      # @param fulfillment_item [Spree::FulfillmentItem]
      # @param requested [Hash{Integer => Integer}] units already asked for in
      #   this request, keyed by fulfillment item id
      # @return [Integer]
      def returnable_quantity_for(fulfillment_item, requested: {})
        returned = Spree::ReturnLineItem.
                   joins(:return).
                   where(fulfillment_item_id: fulfillment_item.id).
                   where.not(Spree::Return.table_name => { status: 'canceled' }).
                   sum(:quantity)
        exchanged = Spree::ExchangeLineItem.
                    joins(:exchange).
                    where(fulfillment_item_id: fulfillment_item.id).
                    where.not(Spree::Exchange.table_name => { status: 'canceled' }).
                    sum(:quantity)

        fulfillment_item.quantity.to_i - returned - exchanged - requested.fetch(fulfillment_item.id, 0)
      end

      # Checks each item's quantity against what is still returnable and
      # fails with the item's name when it is not.
      #
      # @param items [Array<Hash>] `[{ fulfillment_item:, quantity: }]`
      # @param action [String] 'returned' or 'exchanged', for the message
      def ensure_returnable_quantities(items, action:)
        requested = Hash.new(0)

        items.each do |item|
          fulfillment_item = item[:fulfillment_item]
          available = returnable_quantity_for(fulfillment_item, requested: requested)
          if item[:quantity] > available
            failure(order, "Only #{[available, 0].max} of #{fulfillment_item.variant.name} can be #{action}")
          end

          requested[fulfillment_item.id] += item[:quantity]
        end
      end
    end
  end
end
