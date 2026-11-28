module Spree
  module GiftCardRecipients
    # Carries who each gift card line is for from the cart onto the order it
    # becomes, at checkout and when staff copy a cart into a draft order, so
    # the cards the paid order issues reach the person the buyer named.
    class CopyFromCart
      # Copied verbatim rather than validated again: the send date was
      # checked when the buyer chose it, and a cart left open for a few days
      # must not fail checkout for it.
      #
      # @param line_item_map [Hash{Spree::LineItem => Spree::LineItem}] cart
      #   line → its copy on the order
      def self.call(line_item_map:, **)
        recipients = Spree::GiftCardRecipient.where(line_item_id: line_item_map.keys.map(&:id)).index_by(&:line_item_id)
        return if recipients.empty?

        rows = line_item_map.filter_map do |cart_line_item, line_item|
          recipient = recipients[cart_line_item.id]
          next unless recipient

          recipient.attributes.slice(*Spree::GiftCardRecipient::ATTRIBUTES, 'store_id').merge('line_item_id' => line_item.id)
        end
        Spree::GiftCardRecipient.insert_all!(rows)
      end
    end
  end
end
