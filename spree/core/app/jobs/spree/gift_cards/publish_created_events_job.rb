module Spree
  module GiftCards
    # Publishes `gift_card.created` for the cards a batch bulk-inserted, which
    # skipped the callbacks that would have published it.
    #
    # Continuable: the cursor is the last card published, so a retried or
    # interrupted run resumes there instead of losing or repeating the rest of
    # a batch of up to `gift_card_batch_limit` cards. A card whose event fails
    # to publish is reported and skipped, so it cannot hold back the others;
    # a failing query still raises and is retried.
    class PublishCreatedEventsJob < ::Spree::BaseJob
      include ActiveJob::Continuable

      queue_as Spree.queues.gift_cards

      # @param batch_id [Integer] the gift card batch
      # @param after_id [Integer, nil] publish only for the batch's cards after this one
      def perform(batch_id, after_id: nil)
        @batch = Spree::GiftCardBatch.find(batch_id)

        step :publish, start: after_id
      end

      private

      def publish(step)
        gift_cards = @batch.gift_cards.includes(:store)
        gift_cards = gift_cards.where(Spree::GiftCard.arel_table[:id].gt(step.cursor)) if step.cursor

        gift_cards.find_each(order: :asc) do |gift_card|
          publish_created(gift_card)
          step.set!(gift_card.id)
        end
      end

      def publish_created(gift_card)
        gift_card.publish_event("#{Spree::GiftCard.event_prefix}.created")
      # Retried by Spree::BaseJob, resuming from the cursor instead of skipping the card.
      rescue *TRANSIENT_ERRORS
        raise
      rescue StandardError => e
        Rails.error.report(e, handled: true, context: { gift_card_id: gift_card.id }, source: 'spree.core')
      end
    end
  end
end
