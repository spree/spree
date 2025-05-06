module Spree
  module GiftCards
    class BulkGenerateJob < ::Spree::BaseJob
      queue_as Spree.queues.gift_cards_bulk_generate

      def perform(id)
        gift_cards_batch = Spree::GiftCardBatch.find(id)

        with_optional_tenant(gift_cards_batch) do
          gift_cards_batch.create_gift_cards
        end
      end

      private

      def with_optional_tenant(gift_cards_batch, &block)
        if defined?(ActsAsTenant)
          ActsAsTenant.with_tenant(gift_cards_batch.tenant, &block)
        else
          block.call
        end
      end
    end
  end
end
