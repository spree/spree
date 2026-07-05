module Spree
  class Order < Spree.base_class
    module GiftCard
      extend ActiveSupport::Concern

      included do
        # one GiftCard can be used on many orders, until it runs out
        belongs_to :gift_card, class_name: 'Spree::GiftCard', optional: true

        money_methods :gift_card_total
      end

      # Returns the total amount of the gift card applied to the order
      # @return [Decimal]
      def gift_card_total
        return 0.to_d unless gift_card.present?

        store_credit_ids = payments.store_credits.valid.pluck(:source_id)
        store_credits = Spree::StoreCredit.where(id: store_credit_ids, originator: gift_card)

        store_credits.sum(:amount)
      end

      # Applies a gift card to the order
      # @param gift_card [Spree::GiftCard] the gift card to apply
      # @return [Spree::Order] the order with the gift card applied
      def apply_gift_card(gift_card)
        Spree.gift_card_apply_service.call(gift_card: gift_card, order: self)
      end

      # Removes a gift card from the order
      # @return [Spree::Order] the order with the gift card removed
      def remove_gift_card
        Spree.gift_card_remove_service.call(order: self)
      end

      # Recalculates the gift card payment amount based on the current order total.
      # Updates the existing payment in place instead of remove + re-apply
      # to avoid creating unnecessary invalid payment records.
      def recalculate_gift_card
        return unless gift_card.present?

        payment = payments.checkout.store_credits.where(source: gift_card.store_credits).first
        return unless payment

        # with_lock acquires a row lock and wraps in a transaction.
        # The entire read-compute-write must be inside the lock to prevent
        # stale amount_remaining from concurrent requests.
        gift_card.with_lock do
          new_amount = [gift_card.amount_remaining + payment.amount, total].min
          next if payment.amount == new_amount

          difference = new_amount - payment.amount
          # Uses update_column to bypass Payment#max_amount validation which
          # can fail during recalculation due to stale in-memory order state.
          # Bounds are enforced via min() above.
          payment.update_column(:amount, new_amount)
          payment.source.update_column(:amount, new_amount)
          gift_card.amount_used += difference
          gift_card.save!
        end
      end

      def redeem_gift_card
        return unless gift_card.present?

        Spree.gift_card_redeem_service.call(gift_card: gift_card)
      end
    end
  end
end
