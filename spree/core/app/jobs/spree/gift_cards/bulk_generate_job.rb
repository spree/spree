module Spree
  module GiftCards
    class BulkGenerateJob < ::Spree::BaseJob
      queue_as Spree.queues.gift_cards

      # @param id [Integer] the gift card batch
      # @param publish_events [Boolean] whether lifecycle events were on when the batch was created
      def perform(id, publish_events: true)
        gift_cards_batch = Spree::GiftCardBatch.find(id)

        gift_cards_batch.create_gift_cards(publish_events: publish_events)
      end
    end
  end
end
