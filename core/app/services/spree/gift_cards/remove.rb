module Spree
  module GiftCards
    class Remove
      prepend Spree::ServiceModule::Base

      def call(order:)
        return failure(:remove_gift_card_on_completed_order_error) if order.completed?
        return success(true) if order.gift_card.nil?

        gift_card = order.gift_card

        return failure(:gift_card_not_found) if gift_card.nil?

        order.with_lock do
          payments = order.payments.checkout.store_credits.where(source: gift_card.store_credits)
          payment_total = payments.sum(:amount)
          payments.each(&:invalidate!)

          gift_card.with_lock do
            gift_card.amount_used -= payment_total
            gift_card.save!
          end

          # we need to destroy the store credits here because they are not associated with the order
          # and we need to remove them from the gift card
          # TODO: rather than destroying the store credits, we should void them
          payments.each do |payment|
            payment.source.destroy!
          end

          order.update!(gift_card: nil)
        end

        success(true)
      end
    end
  end
end
