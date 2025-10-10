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
        Spree::Dependencies.gift_card_apply_service.constantize.call(gift_card: gift_card, order: self)
      end

      # Removes a gift card from the order
      # @return [Spree::Order] the order with the gift card removed
      def remove_gift_card
        Spree::Dependencies.gift_card_remove_service.constantize.call(order: self)
      end

      def recalculate_gift_card
        applied_gift_card = gift_card

        remove_gift_card
        apply_gift_card(applied_gift_card)
      end

      def redeem_gift_card
        return unless gift_card.present?

        Spree::Dependencies.gift_card_redeem_service.constantize.call(gift_card: gift_card)
      end
    end
  end
end
