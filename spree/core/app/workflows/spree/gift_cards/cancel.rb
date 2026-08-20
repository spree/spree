module Spree
  module GiftCards
    # Voids a gift card so it can no longer be spent. Refuses a card that has
    # already been spent against, because cancelling it would silently take
    # back value the customer has used.
    class Cancel < Spree::Workflow
      hooks :validate, :after_cancel

      # @param gift_card [Spree::GiftCard]
      # @return [Spree::ServiceModule::Result] value is the gift card
      def perform(gift_card:)
        super

        step :ensure_cancellable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_canceled
          run_hooks :after_cancel
        end

        gift_card.publish_event('gift_card.canceled')
        success(gift_card)
      end

      private

      def ensure_cancellable
        failure(gift_card, :gift_card_already_canceled) if gift_card.canceled?
        failure(gift_card, :gift_card_already_redeemed) unless gift_card.status == 'active'

        # A card drawn against by Spree::GiftCards::Apply keeps the active
        # status until the order that spent it completes, so status alone
        # would let a card funding a live checkout be cancelled underneath it.
        failure(gift_card, :gift_card_already_redeemed) unless gift_card.amount_used.zero?
      end

      def mark_canceled
        failure(gift_card) unless gift_card.update(status: 'canceled')
      end
    end
  end
end
