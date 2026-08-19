module Spree
  module GiftCards
    # Marks a gift card spent. Called once the order that consumed it is
    # placed, so it runs after the money has already been taken off the card
    # by Spree::GiftCards::Apply — this records the outcome.
    #
    # A card is only fully redeemed when nothing is left on it; while a
    # balance remains it becomes partially redeemed and stays spendable. The
    # partial case deliberately republishes on every redemption, because each
    # one is a separate spend the merchant may want to react to.
    class Redeem < Spree::Workflow
      hooks :validate, :after_redeem

      # @param gift_card [Spree::GiftCard]
      # @return [Spree::ServiceModule::Result] value is the gift card
      def perform(gift_card:)
        super

        step :ensure_redeemable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_redeemed
          run_hooks :after_redeem
        end

        gift_card.publish_event("gift_card.#{fully_redeemed? ? 'redeemed' : 'partially_redeemed'}")
        success(gift_card)
      end

      private

      def ensure_redeemable
        failure(gift_card, :gift_card_already_redeemed) if gift_card.redeemed?
        failure(gift_card, :gift_card_canceled) if gift_card.canceled?
      end

      # Read once, before the write: which event fires has to describe the
      # same spend the status does.
      def fully_redeemed?
        return @fully_redeemed unless @fully_redeemed.nil?

        @fully_redeemed = gift_card.amount_remaining.zero?
      end

      # redeemed_at marks the moment the card was spent out, so it is only
      # stamped on full redemption — a partial spend leaves it unset.
      def mark_redeemed
        attributes = if fully_redeemed?
                       { status: 'redeemed', redeemed_at: Time.current }
                     else
                       { status: 'partially_redeemed' }
                     end

        failure(gift_card) unless gift_card.update(attributes)
      end
    end
  end
end
