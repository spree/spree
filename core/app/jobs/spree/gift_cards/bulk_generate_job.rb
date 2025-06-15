module Spree
  module GiftCards
    class BulkGenerateJob < ::Spree::BaseJob
      queue_as Spree.queues.gift_cards

      def perform(id)
        gift_cards_batch = Spree::GiftCardBatch.find(id)

        gift_cards_batch.create_gift_cards
      end
    end
  end
end
