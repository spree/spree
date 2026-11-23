module Spree
  module GiftCards
    # Deletes a gift card. A card applied to an open cart or draft order is
    # taken off it first through Spree.gift_card_remove_workflow, which voids
    # the store credit payment made from the card and restores the amount
    # due. Deleting the card while leaving that payment would let the order
    # be placed paid by a card that no longer exists, and refusing instead
    # would leave a card on an abandoned guest cart undeletable, because
    # holds never expire on their own.
    #
    # Refused while a checkout is completing with the card (its totals are
    # fixed and money may be at the gateway), and for a card the model will
    # not delete (redeemed or partially redeemed). A refusal rolls back any
    # hold already released, so nothing changes.
    class Destroy < Spree::Workflow
      hooks :validate, :after_destroy

      # Carts and draft orders the card was taken off.
      # @return [Array<Spree::Cart, Spree::Order>]
      attr_reader :released_holds

      # @param gift_card [Spree::GiftCard]
      # @return [Spree::ServiceModule::Result] value is the destroyed gift card
      def perform(gift_card:)
        super

        run_hooks :validate

        # Holds are locked before the card, the order Spree::GiftCards::Apply
        # and Remove use, so this cannot deadlock against either. The card
        # stays locked from the check to the delete, so a checkout cannot
        # apply it in between.
        ApplicationRecord.transaction do
          step :lock_holds
          step :release_open_holds
          step :lock_gift_card
          step :ensure_not_being_completed
          step :destroy_gift_card
          run_hooks :after_destroy
        end

        success(gift_card)
      end

      private

      def lock_holds
        @holds = gift_card.open_holds

        @holds.group_by(&:class).each do |klass, records|
          klass.where(id: records.map(&:id)).order(:id).lock.to_a
        end
      end

      # Re-reads each hold under its lock: the list was gathered before it,
      # so the hold may have moved on to another card, completed or claimed
      # completion since. Those are skipped, and a claimed one then fails
      # +ensure_not_being_completed+.
      def release_open_holds
        @released_holds = []

        @holds.each do |hold|
          hold.reload
          next unless hold.gift_card_id == gift_card.id
          next if hold.completed? || claimed_for_completion?(hold)

          result = Spree.gift_card_remove_workflow.call(order: hold)
          failure(gift_card, :gift_card_held_by_another_order) if result.failure?

          @released_holds << hold
        end
      end

      def lock_gift_card
        gift_card.lock!
      end

      def ensure_not_being_completed
        failure(gift_card, :gift_card_held_by_another_order) if gift_card.holds_being_completed.any?
      end

      # The model's before_destroy guard has the final say (a redeemed card,
      # or any hold left) and adds the reason to the card's errors.
      def destroy_gift_card
        failure(gift_card) unless gift_card.destroy
      end

      # Mirrors Spree::GiftCard#holds_being_completed.
      def claimed_for_completion?(hold)
        return hold.completion_claimed? if hold.is_a?(Spree::Cart)

        hold.cart&.reload&.completion_claimed? || false
      end
    end
  end
end
