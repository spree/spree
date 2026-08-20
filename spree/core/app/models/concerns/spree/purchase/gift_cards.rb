module Spree
  module Purchase
    # Gift-card application surface shared by Spree::Cart and Spree::Order.
    # One gift card can be used on many carts/orders, until it runs out.
    module GiftCards
      extend ActiveSupport::Concern

      included do
        belongs_to :gift_card, class_name: 'Spree::GiftCard', optional: true

        money_methods :gift_card_total
      end

      # The amount of the gift card applied to this record.
      #
      # @return [BigDecimal]
      def gift_card_total
        return 0.to_d unless gift_card.present?

        store_credit_ids = payments.store_credits.valid.pluck(:source_id)
        Spree::StoreCredit.where(id: store_credit_ids, originator: gift_card).sum(:amount)
      end

      def total_minus_gift_cards
        total - gift_card_total
      end

      # @param gift_card [Spree::GiftCard]
      def apply_gift_card(gift_card)
        Spree.gift_card_apply_workflow.call(gift_card: gift_card, order: self)
      end

      def remove_gift_card
        Spree.gift_card_remove_workflow.call(order: self)
      end

      # @return [Spree::ServiceModule::Result, nil] the caller decides what a
      #   refusal means; Orders::Complete reports it rather than failing the
      #   order, since the card was already drawn down when it was applied.
      def redeem_gift_card
        return unless gift_card.present?

        Spree.gift_card_redeem_workflow.call(gift_card: gift_card)
      end

      # In-lock read-compute-write keeping the gift-card payment amount in
      # sync with the current total. Updates the payment in place instead
      # of remove + re-apply to avoid creating invalid payment records.
      def recalculate_gift_card
        return unless gift_card.present?

        payment = payments.checkout.store_credits.where(source: gift_card.store_credits).first
        return unless payment

        gift_card.with_lock do
          new_amount = [gift_card.amount_remaining + payment.amount, total].min
          next if payment.amount == new_amount

          difference = new_amount - payment.amount
          # update_column bypasses Payment#max_amount validation which can
          # fail on stale in-memory state; bounds enforced via min() above.
          payment.update_column(:amount, new_amount)
          payment.source.update_column(:amount, new_amount)
          gift_card.amount_used += difference
          gift_card.save!
        end
      end
    end
  end
end
